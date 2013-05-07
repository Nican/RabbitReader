package main

import "fmt"
import "rreader"

type User struct {
	id   uint32
	name string
}

func CreateUser(username string) User {

	_, res, err := rreader.GetConnection().Query("INSERT INTO `users`(`name`) VALUES ('%s')", username)

	if err != nil {
		panic(err)
	}

	id := res.InsertId()

	return User{id: uint32(id), name: username}

}

func importData() {
	CreateUser("nican")
	err := rreader.SQLImport(1, "takeout.zip")

	if err != nil {
		panic(err)
	}
}

func main() {
	fmt.Printf("Starting Greader\n")
	rreader.OpenDB()

	//importData()
	rreader.StartWebserver()
	//rreader.UpdateFeeds()

	fmt.Printf("Finished Greader")
}
