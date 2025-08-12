package mq

import (
	"context"
	"encoding/json"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
)

type RabbitMQPublisher struct {
	conn *amqp.Connection
}

func NewRabbitMQPublisher(url string) (*RabbitMQPublisher, error) {
	// NEW: gunakan url yang diberikan, jangan hardcode
	conn, err := amqp.Dial(url)
	if err != nil {
		return nil, err
	}
	return &RabbitMQPublisher{conn: conn}, nil
}

func (p *RabbitMQPublisher) Publish(queueName string, taskMessage map[string]string) error {
	ch, err := p.conn.Channel()
	if err != nil {
		return err
	}
	defer ch.Close()

	// Queue durable
	q, err := ch.QueueDeclare(queueName, true, false, false, false, nil)
	if err != nil {
		return err
	}

	body, err := json.Marshal(taskMessage)
	if err != nil {
		return err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// NEW: pesan persisten + metadata
	return ch.PublishWithContext(ctx, "", q.Name, false, false, amqp.Publishing{
		ContentType:  "application/json",
		DeliveryMode: amqp.Persistent,
		Timestamp:    time.Now(),
		MessageId:    time.Now().Format("20060102T150405.000000000"),
		Body:         body,
	})
}

func (p *RabbitMQPublisher) Close() {
	_ = p.conn.Close()
}
