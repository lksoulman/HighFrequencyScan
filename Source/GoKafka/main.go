package main

import (
	"log"
	"os"
	"strings"
	"unsafe"

	"github.com/Shopify/sarama"
)

//import "C"

var (
	logger = log.New(os.Stderr, "[srama]", log.LstdFlags)
)

func main() {}

func mytest() {
	sarama.Logger = logger
	config := sarama.NewConfig()
	config.Producer.RequiredAcks = sarama.WaitForAll
	config.Producer.Partitioner = sarama.NewRandomPartitioner
	config.Producer.Return.Successes = true

	msg := &sarama.ProducerMessage{}
	msg.Topic = "hello"
	msg.Partition = int32(-1)
	msg.Key = sarama.StringEncoder("key")
	msg.Value = sarama.ByteEncoder("测试数据")

	producer, err := sarama.NewSyncProducer(strings.Split("127.0.0.1:9092", ","), config)
	if err != nil {
		logger.Println("Failed to produce message: %s", err.Error())
		os.Exit(500)
	}
	defer producer.Close()

	partition, offset, err := producer.SendMessage(msg)
	if err != nil {
		logger.Println("Failed to produce message: ", err)
	}
	logger.Printf("partition=%d, offset=%d\n", partition, offset)
}

//export ConnectKafka
func ConnectKafka(servers string, topic string) unsafe.Pointer {
	config := sarama.NewConfig()
	config.Producer.RequiredAcks = sarama.WaitForAll
	config.Producer.Partitioner = sarama.NewRandomPartitioner
	config.Producer.Return.Successes = true
	producer, err := sarama.NewAsyncProducer(strings.Split(servers, ","), config)
	if err != nil {
		return nil
	}
	return unsafe.Pointer(&producer)
}

//export SendMessage
func SendMessage(client unsafe.Pointer, msg string) {

}

//Disconnec function: disconnect the server .
func Disconnec(client unsafe.Pointer) {
	tmp := (*sarama.AsyncProducer)(client)
	p := *tmp
	p.Close()
}
