package rreader

import (
	_ "database/sql"
	"github.com/ziutek/mymysql/thrsafe"
	"github.com/ziutek/mymysql/mysql"
	_ "github.com/ziutek/mymysql/native" // Native engine
	//"io/ioutil"
	"encoding/json"
	"os"
)


var gConn mysql.Conn

func GetConnection() mysql.Conn {
	return gConn
}

type ConfigFile struct {
	Mysql MySQLConfig
}

type MySQLConfig struct {
	LocalAddr string
	Address string
	User string
	Password string
	Database string
}

func OpenDB() {
	file, err := os.Open("config.json")
	if err != nil {
	   	panic(err)
	}
	
	var config ConfigFile
	
	decoder := json.NewDecoder(file)
	err = decoder.Decode(&config)
	
	if err != nil {
	   	panic(err)
	}

	gConn = thrsafe.New("tcp", 
		config.Mysql.LocalAddr, 
		config.Mysql.Address, 
		config.Mysql.User, 
		config.Mysql.Password, 
		config.Mysql.Database )
	
	err = gConn.Connect()
	if err != nil {
		panic(err)
	}
}

