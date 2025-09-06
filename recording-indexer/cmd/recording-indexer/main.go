package main

import (
    "context"
    "database/sql"
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "os"
    "regexp"
    "strconv"
    "time"

    _ "github.com/lib/pq"

	"github.com/aws/aws-sdk-go-v2/aws"
	awscfg "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

func envInt(k string, def int) int {
	if v := os.Getenv(k); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return def
}

func newS3(endpoint, access, secret string) (*s3.Client, error) {
	cfg, err := awscfg.LoadDefaultConfig(
		context.TODO(),
		awscfg.WithRegion("us-east-1"),
		awscfg.WithEndpointResolverWithOptions(
			aws.EndpointResolverWithOptionsFunc(func(service, region string, _ ...interface{}) (aws.Endpoint, error) {
				return aws.Endpoint{URL: endpoint, SigningRegion: "us-east-1"}, nil
			}),
		),
		awscfg.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(access, secret, "")),
	)
	if err != nil {
		return nil, err
	}
	return s3.NewFromConfig(cfg, func(o *s3.Options) { o.UsePathStyle = true }), nil
}

func ensureBucket(ctx context.Context, cli *s3.Client, bucket string) error {
	_, err := cli.HeadBucket(ctx, &s3.HeadBucketInput{Bucket: &bucket})
	if err == nil {
		return nil
	}
	_, err = cli.CreateBucket(ctx, &s3.CreateBucketInput{Bucket: &bucket})
	return err
}

var (
	reFlat   = regexp.MustCompile(`^([A-Za-z0-9_-]+)_(\d{8}_\d{6})\.mp4$`)
	reFolder = regexp.MustCompile(`^([A-Za-z0-9_-]+)/\d{4}/\d{2}/\d{2}/.*_(\d{8}_\d{6})\.mp4$`)
)

func parseKey(key string, segmentDur time.Duration) (cam string, start, end time.Time, ok bool) {
	if m := reFlat.FindStringSubmatch(key); m != nil {
		cam = m[1]
		ts := m[2] // YYYYMMDD_HHMMSS
		t, err := time.ParseInLocation("20060102_150405", ts, time.Local)
		if err != nil {
			return "", time.Time{}, time.Time{}, false
		}
		return cam, t, t.Add(segmentDur), true
	}
	if m := reFolder.FindStringSubmatch(key); m != nil {
		cam = m[1]
		ts := m[2]
		t, err := time.ParseInLocation("20060102_150405", ts, time.Local)
		if err != nil {
			return "", time.Time{}, time.Time{}, false
		}
		return cam, t, t.Add(segmentDur), true
	}
	return "", time.Time{}, time.Time{}, false
}

func upsert(db *sql.DB, cam string, start, end time.Time, key string, size int64) error {
	_, err := db.Exec(`
		INSERT INTO recordings (camera_id, started_at, ended_at, s3_key, size_bytes)
		VALUES ($1,$2,$3,$4,$5)
		ON CONFLICT (camera_id, started_at) DO UPDATE
		SET ended_at=EXCLUDED.ended_at, s3_key=EXCLUDED.s3_key, size_bytes=EXCLUDED.size_bytes
	`, cam, start, end, key, size)
	return err
}

func scanOnce(ctx context.Context, cli *s3.Client, bucket string, segDur time.Duration, db *sql.DB) error {
	p := s3.NewListObjectsV2Paginator(cli, &s3.ListObjectsV2Input{
		Bucket: &bucket,
	})
	total, upserts, skipped := 0, 0, 0

	for p.HasMorePages() {
		out, err := p.NextPage(ctx)
		if err != nil {
			return err
		}
		for _, it := range out.Contents {
			total++
			key := aws.ToString(it.Key)
			cam, start, end, ok := parseKey(key, segDur)
			if !ok {
				if total <= 10 { // batasi supaya log nggak banjir
					log.Printf("skip key (unrecognized): %q", key)
				}
				skipped++
				continue
			}
			if err := upsert(db, cam, start, end, key, aws.ToInt64(it.Size)); err != nil {
				return fmt.Errorf("upsert %s: %w", key, err)
			}
			upserts++
		}
	}
	log.Printf("scan summary: total=%d upserts=%d skipped=%d\n", total, upserts, skipped)
	return nil
}

func main() {
	endpoint := os.Getenv("MINIO_ENDPOINT") // http://minio:9000
	access := os.Getenv("MINIO_ACCESS_KEY")
	secret := os.Getenv("MINIO_SECRET_KEY")
	bucket := os.Getenv("ARCHIVE_BUCKET")     // video-archive
	segSec := envInt("SEGMENT_SECONDS", 3600) // samakan dgn ffmpeg -segment_time
	dsn := os.Getenv("POSTGRES_DSN")          // host=db port=5432 user=admin password=secret dbname=cctv_db sslmode=disable
	interval := time.Duration(envInt("SCAN_INTERVAL_SEC", 30)) * time.Second

	if endpoint == "" || access == "" || secret == "" || bucket == "" || dsn == "" {
		log.Fatal("env MINIO_ENDPOINT/MINIO_ACCESS_KEY/MINIO_SECRET_KEY/ARCHIVE_BUCKET/POSTGRES_DSN wajib diisi")
	}

	cli, err := newS3(endpoint, access, secret)
	if err != nil {
		log.Fatal(err)
	}
	if err := ensureBucket(context.Background(), cli, bucket); err != nil {
		log.Fatalf("ensure bucket %s: %v", bucket, err)
	}

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

    log.Printf("recording-indexer start: bucket=%s, interval=%s, seg=%ds\n", bucket, interval, segSec)

    // Optional: HTTP notify endpoint
    httpAddr := os.Getenv("INDEXER_HTTP_ADDR") // e.g. :8091
    if httpAddr != "" {
        mux := http.NewServeMux()
        mux.HandleFunc("/api/notify", func(w http.ResponseWriter, r *http.Request) {
            if r.Method != "POST" { w.WriteHeader(405); return }
            type req struct{ S3Key string `json:"s3_key"`; Size int64 `json:"size_bytes"` }
            var q req
            if err := json.NewDecoder(r.Body).Decode(&q); err != nil { w.WriteHeader(400); return }
            cam, start, end, ok := parseKey(q.S3Key, time.Duration(segSec)*time.Second)
            if !ok { w.WriteHeader(400); return }
            if err := upsert(db, cam, start, end, q.S3Key, q.Size); err != nil { w.WriteHeader(500); return }
            w.WriteHeader(204)
        })
        go func() {
            log.Printf("indexer HTTP listen %s\n", httpAddr)
            if err := http.ListenAndServe(httpAddr, mux); err != nil { log.Println("http error:", err) }
        }()
    }

	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	ctx := context.Background()
	segDur := time.Duration(segSec) * time.Second

	for {
		if err := scanOnce(ctx, cli, bucket, segDur, db); err != nil {
			log.Println("scan error:", err)
		}
		<-ticker.C
	}
}
