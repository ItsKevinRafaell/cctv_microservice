package main
import (
  "fmt"
  "golang.org/x/crypto/bcrypt"
)
func main(){
  pw := []byte("ChangeMe123!")
  h, err := bcrypt.GenerateFromPassword(pw, bcrypt.DefaultCost)
  if err != nil { panic(err) }
  fmt.Println(string(h))
}
