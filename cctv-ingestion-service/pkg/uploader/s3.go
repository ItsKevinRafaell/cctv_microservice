package uploader

import (
	"context"
	"fmt"
	"io"
	"mime/multipart"
	"os"
	"path/filepath"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	awscfg "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

type S3Uploader struct {
	ClientInternal *s3.Client
	ClientPublic   *s3.Client // dipakai untuk presign/public URL
	Bucket         string

	UsePresign    bool
	PresignTTL    time.Duration
	PublicBaseURL string // contoh: http://127.0.0.1:9000
}

func newS3Client(endpoint, accessKey, secretKey string) (*s3.Client, error) {
	cfg, err := awscfg.LoadDefaultConfig(
		context.TODO(),
		awscfg.WithRegion("us-east-1"),
		awscfg.WithEndpointResolverWithOptions(aws.EndpointResolverWithOptionsFunc(
			func(service, region string, options ...interface{}) (aws.Endpoint, error) {
				return aws.Endpoint{URL: endpoint, SigningRegion: "us-east-1"}, nil
			},
		)),
		awscfg.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(accessKey, secretKey, "")),
	)
	if err != nil {
		return nil, err
	}
	return s3.NewFromConfig(cfg, func(o *s3.Options) { o.UsePathStyle = true }), nil
}

func NewS3Uploader(
	internalEndpoint, publicEndpoint, accessKey, secretKey, bucket string,
	usePresign bool, presignTTLSeconds int, publicBaseURL string,
) (*S3Uploader, error) {
	internalCli, err := newS3Client(internalEndpoint, accessKey, secretKey)
	if err != nil {
		return nil, err
	}
	publicCli := internalCli
	if publicEndpoint != "" && publicEndpoint != internalEndpoint {
		publicCli, err = newS3Client(publicEndpoint, accessKey, secretKey)
		if err != nil {
			return nil, err
		}
	}
	if presignTTLSeconds <= 0 {
		presignTTLSeconds = 86400 // default 1 hari
	}
	return &S3Uploader{
		ClientInternal: internalCli,
		ClientPublic:   publicCli,
		Bucket:         bucket,
		UsePresign:     usePresign,
		PresignTTL:     time.Duration(presignTTLSeconds) * time.Second,
		PublicBaseURL:  publicBaseURL,
	}, nil
}

func (u *S3Uploader) ensureBucket(ctx context.Context) error {
	// Coba cek bucket
	_, err := u.ClientInternal.HeadBucket(ctx, &s3.HeadBucketInput{
		Bucket: &u.Bucket,
	})
	if err == nil {
		return nil
	}

	// Buat bucket TANPA CreateBucketConfiguration (MinIO tidak perlu region)
	_, err = u.ClientInternal.CreateBucket(ctx, &s3.CreateBucketInput{
		Bucket: &u.Bucket,
	})
	return err
}

func (u *S3Uploader) Save(file multipart.File, handler *multipart.FileHeader) (string, string, error) {
	ctx := context.TODO()

	// Pastikan folder lokal ada (volume /app/uploads)
	uploadsDir := "/app/uploads"
	if err := os.MkdirAll(uploadsDir, 0755); err != nil {
		return "", "", err
	}

	filename := fmt.Sprintf("%d-%s", time.Now().UnixNano(), handler.Filename)
	localPath := filepath.Join(uploadsDir, filename)

	// Tulis file ke lokal dulu
	dst, err := os.Create(localPath)
	if err != nil {
		return "", "", err
	}
	if _, err := io.Copy(dst, file); err != nil {
		dst.Close()
		return "", "", err
	}
	if _, err := dst.Seek(0, io.SeekStart); err != nil {
		dst.Close()
		return "", "", err
	}

	// Optional: pastikan bucket ada
	_ = u.ensureBucket(ctx)

	// Upload ke S3/MinIO via endpoint internal
	_, err = u.ClientInternal.PutObject(ctx, &s3.PutObjectInput{
		Bucket:      &u.Bucket,
		Key:         &filename,
		Body:        dst,
		ContentType: aws.String("video/mp4"),
	})
	dst.Close()
	if err != nil {
		return "", "", err
	}

	// Bangun URL untuk disimpan ke DB
	var fileURL string
	if u.UsePresign {
		p := s3.NewPresignClient(u.ClientPublic)
		req, err := p.PresignGetObject(ctx, &s3.GetObjectInput{
			Bucket: &u.Bucket,
			Key:    &filename,
		}, s3.WithPresignExpires(u.PresignTTL))
		if err != nil {
			return "", "", err
		}
		fileURL = req.URL
	} else {
		base := u.PublicBaseURL
		if base == "" {
			// fallback kalau tidak di-set
			base = "http://127.0.0.1:9000"
		}
		fileURL = fmt.Sprintf("%s/%s/%s", base, u.Bucket, filename)
	}

	return fileURL, localPath, nil
}
