package main

import "fmt"
import "rreader"
import "os"
import "time"
import "io/ioutil"

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

func importData(fileName string) {
	sql, err := ioutil.ReadFile("mysql.sql")
	
	if err != nil {
		panic(err)
	} 
	
	_, _, err = rreader.GetConnection().Query(string(sql))
	
	if err != nil {
		panic(err)
	}

	CreateUser("nican")
	err = rreader.SQLImport(1, fileName)

	if err != nil {
		panic(err)
	}
}

func updateRepeat(minutes time.Duration){
	for {
		time.Sleep(time.Minute * minutes)
		rreader.UpdateFeeds( 60 * 6 ) //6 hours
	}
}

func printHelp() {
	fmt.Println(`
Usage:
	rrabbit import [filename] -
		Import a Google Reader dump
		
	rrabbit update -
		Update all the loaded feeds
		
	rrabbit web - 
		Starts a web server on localhost:8080
	`)

}

func main() {
	fmt.Printf("Starting Greader\n")
	rreader.OpenDB()
	
	if len(os.Args) == 1 {
		printHelp()
		return
	}
	
	if os.Args[1] == "import" {
		fileName := "takeout.zip"
		
		if len(os.Args) > 2 {
			fileName = os.Args[2]
		}
	
		importData(fileName)
	}
	
	if os.Args[1] == "update" {
		rreader.UpdateFeeds(0)
	}
	
	if os.Args[1] == "web" {
		go updateRepeat(60)
		rreader.StartWebserver()
	}

	fmt.Printf("Finished Greader")
}
