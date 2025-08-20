// internal/storage/s3util.go
package storage

import (
	"context"
	"fmt"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

// S3Util menyederhanakan akses ke MinIO/S3 untuk presign URL dan public URL.
type S3Util struct {
	clientInternal *s3.Client // untuk operasi server-side (opsional)
	clientPublic   *s3.Client // dipakai untuk presign agar host-nya publik
	presigner      *s3.PresignClient
	usePresign     bool
	publicBase     string        // contoh: http://127.0.0.1:9000
	defaultTTL     time.Duration // TTL default untuk presign
}

// newS3Client membuat client S3 dengan endpoint kustom dan path-style,
// cocok untuk MinIO.
func newS3Client(endpoint, access, secret string) (*s3.Client, error) {
	cfg, err := awsconfig.LoadDefaultConfig(
		context.TODO(),
		awsconfig.WithRegion("us-east-1"),
		awsconfig.WithEndpointResolverWithOptions(
			aws.EndpointResolverWithOptionsFunc(func(service, region string, _ ...interface{}) (aws.Endpoint, error) {
				return aws.Endpoint{
					URL:           endpoint,
					SigningRegion: "us-east-1",
				}, nil
			}),
		),
		awsconfig.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(access, secret, "")),
	)
	if err != nil {
		return nil, err
	}
	return s3.NewFromConfig(cfg, func(o *s3.Options) {
		o.UsePathStyle = true // penting untuk MinIO
	}), nil
}

// NewS3Util membuat util dengan dua endpoint:
// - internalEndpoint : dipakai antar-service di dalam Docker network (mis. http://minio:9000)
// - publicEndpoint   : dipakai user/host (mis. http://127.0.0.1:9000)
// presigner dibuat dari client PUBLIC agar presigned URL bisa diakses dari host.
func NewS3Util(
	internalEndpoint string,
	publicEndpoint string,
	access string,
	secret string,
	publicBase string,
	usePresign bool,
	defaultTTL time.Duration,
) (*S3Util, error) {
	inCli, err := newS3Client(internalEndpoint, access, secret)
	if err != nil {
		return nil, err
	}

	pubCli := inCli
	if publicEndpoint != "" && publicEndpoint != internalEndpoint {
		if pubCli, err = newS3Client(publicEndpoint, access, secret); err != nil {
			return nil, err
		}
	}

	return &S3Util{
		clientInternal: inCli,
		clientPublic:   pubCli,
		presigner:      s3.NewPresignClient(pubCli), // presign via endpoint publik
		usePresign:     usePresign,
		publicBase:     publicBase,
		defaultTTL:     defaultTTL,
	}, nil
}

// Presign mengembalikan URL akses untuk objek.
// - Jika usePresign=true => presigned URL (TTL = argumen ttl atau defaultTTL).
// - Jika usePresign=false => URL publik langsung (publicBase/bucket/key).
func (u *S3Util) Presign(bucket, key string, ttl time.Duration) (string, error) {
	if u.usePresign {
		if ttl <= 0 {
			ttl = u.defaultTTL
		}
		req, err := u.presigner.PresignGetObject(
			context.TODO(),
			&s3.GetObjectInput{Bucket: &bucket, Key: &key},
			s3.WithPresignExpires(ttl),
		)
		if err != nil {
			return "", err
		}
		return req.URL, nil
	}
	return u.PublicURL(bucket, key), nil
}

// PublicURL membangun URL publik non-presign: publicBase/bucket/key.
func (u *S3Util) PublicURL(bucket, key string) string {
	base := u.publicBase
	if base == "" {
		base = "http://127.0.0.1:9000"
	}
	return fmt.Sprintf("%s/%s/%s", base, bucket, key)
}

// EnsureBucket memastikan bucket tersedia (coba HeadBucket, jika gagal => CreateBucket).
// Aman dipanggil saat startup.
func (u *S3Util) EnsureBucket(ctx context.Context, bucket string) error {
	if u.clientInternal == nil {
		return fmt.Errorf("clientInternal is nil")
	}
	_, err := u.clientInternal.HeadBucket(ctx, &s3.HeadBucketInput{Bucket: &bucket})
	if err == nil {
		return nil
	}
	_, err = u.clientInternal.CreateBucket(ctx, &s3.CreateBucketInput{Bucket: &bucket})
	return err
}
