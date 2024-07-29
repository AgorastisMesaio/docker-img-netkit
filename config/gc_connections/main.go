package main

import (
	"encoding/base64"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os/exec"
	"sort"
	"strconv"
	"strings"
	"text/template"

	"github.com/gin-gonic/gin"
)

// Server addresses
var (
	guacamoleURL string
	guacUsername string
	guacPassword string
	port         string
)

type Connection struct {
	Identifier int    `json:"identifier"`
	Name       string `json:"name"`
	Protocol   string `json:"protocol"`
}

type ConnectionResponse struct {
	Name       string `json:"name"`
	Identifier string `json:"identifier"`
	Protocol   string `json:"protocol"`
}

type DockerContainer struct {
	ID              string          `json:"Id"`
	Names           []string        `json:"Names"`
	Ports           []Port          `json:"Ports"`
	NetworkSettings NetworkSettings `json:"NetworkSettings"`
}

type Port struct {
	IP          string `json:"IP"`
	PrivatePort uint16 `json:"PrivatePort"`
	PublicPort  uint16 `json:"PublicPort"`
	Type        string `json:"Type"`
}

type NetworkSettings struct {
	Networks map[string]Network `json:"Networks"`
}

type Network struct {
	IPAddress string `json:"IPAddress"`
}

func main() {
	flag.StringVar(&guacamoleURL, "url", "", "Guacamole server URL")
	flag.StringVar(&guacUsername, "username", "", "Guacamole username")
	flag.StringVar(&guacPassword, "password", "", "Guacamole password")
	flag.StringVar(&port, "port", "8090", "Server port") // Default port I listen: 8090
	flag.Parse()

	if guacamoleURL == "" || guacUsername == "" || guacPassword == "" {
		log.Fatal("Guacamole URL, username, and password must be provided as arguments")
	}

	router := gin.Default()

	// Serve static files from the "static" directory
	router.Static("/static", "./static")

	// Register the connectionURL function
	router.SetFuncMap(template.FuncMap{
		"connectionURL": connectionURL,
	})

	router.LoadHTMLFiles("templates/index.html")

	router.GET("/", func(c *gin.Context) {
		// log.Println("Handling GET request for /")
		connections, err := fetchConnections()
		if err != nil {
			log.Printf("Error fetching connections: %v\n", err)
			c.String(http.StatusInternalServerError, err.Error())
			return
		}
		// log.Printf("Fetched connections: %v\n", connections)

		// Sort connections by Identifier
		sort.Slice(connections, func(i, j int) bool {
			return connections[i].Identifier < connections[j].Identifier
		})

		c.HTML(http.StatusOK, "index.html", gin.H{
			"connections": connections,
		})
	})

	router.GET("/netkit", func(c *gin.Context) {
		log.Println("Handling GET request for /netkit")
		connections, err := fetchConnections()
		if err != nil {
			log.Printf("Error fetching connections: %v\n", err)
			c.String(http.StatusInternalServerError, err.Error())
			return
		}
		for _, conn := range connections {
			if strings.Contains(conn.Name, "netkit") && conn.Protocol == "ssh" {
				url := connectionURL(conn.Identifier)
				c.String(http.StatusOK, url)
				return
			}
		}
		c.String(http.StatusNotFound, "No matching connection found")
	})

	router.GET("/docker", func(c *gin.Context) {
		containers, err := fetchDockerContainers()
		if err != nil {
			log.Printf("Error fetching Docker containers: %v\n", err)
			c.String(http.StatusInternalServerError, err.Error())
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"containers": containers,
		})
	})

	log.Printf("Server started at :%s\n", port)
	log.Fatal(router.Run(":" + port))
}

func fetchConnections() ([]Connection, error) {
	//log.Println("Fetching auth token")
	authToken, err := getAuthToken()
	if err != nil {
		return nil, err
	}
	// log.Printf("Obtained auth token: %s\n", authToken)

	log.Println("Fetching connection data from Guacamole")
	cmd := exec.Command("curl", "-s", "-G", fmt.Sprintf("%s/api/session/data/postgresql/connections", guacamoleURL), "--data-urlencode", fmt.Sprintf("token=%s", authToken))
	output, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("Curl command error: %s\n", string(output))
		return nil, fmt.Errorf("error fetching connections: %w", err)
	}
	// log.Printf("Raw connection data: %s\n", string(output))

	var rawConnections map[string]ConnectionResponse
	if err := json.Unmarshal(output, &rawConnections); err != nil {
		return nil, err
	}

	var connections []Connection
	for key, conn := range rawConnections {
		id, _ := strconv.Atoi(key)
		connections = append(connections, Connection{
			Identifier: id,
			Name:       conn.Name,
			Protocol:   conn.Protocol,
		})
	}
	// log.Printf("Parsed connections: %v\n", connections)
	log.Printf("Parsed connections: %d\n", len(connections))

	return connections, nil
}

func getAuthToken() (string, error) {
	// log.Println("Requesting auth token")
	cmd := exec.Command("curl", "-s", "-X", "POST", "-d", fmt.Sprintf("username=%s&password=%s", guacUsername, guacPassword), fmt.Sprintf("%s/api/tokens", guacamoleURL))
	output, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("Curl command error: %s\n", string(output))
		return "", fmt.Errorf("error fetching the token: %w", err)
	}
	// log.Printf("Raw auth token response: %s\n", string(output))

	var response map[string]interface{}
	if err := json.Unmarshal(output, &response); err != nil {
		return "", err
	}
	// log.Printf("Parsed auth token response: %v\n", response)

	authToken, ok := response["authToken"].(string)
	if !ok {
		return "", fmt.Errorf("failed to obtain auth token")
	}
	// log.Printf("Auth token: %s\n", authToken)

	return authToken, nil
}

func connectionURL(connectionID int) string {
	encoded := base64.StdEncoding.EncodeToString([]byte(fmt.Sprintf("%d\000c\000postgresql", connectionID)))
	url := fmt.Sprintf("%s/#/client/%s", guacamoleURL, encoded)
	// log.Printf("Generated URL for connection %d: %s\n", connectionID, url)
	return url
}

// Future - under investigation
func fetchDockerContainers() ([]DockerContainer, error) {
	cmd := exec.Command("curl", "-s", "--unix-socket", "/var/run/docker.sock", "http://localhost/containers/json?all=true")
	output, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("Curl command error: %s\n", string(output))
		return nil, fmt.Errorf("error fetching Docker containers: %w", err)
	}

	//log.Printf("Docker API response: %s\n", string(output))

	var containers []DockerContainer
	if err := json.Unmarshal(output, &containers); err != nil {
		log.Printf("Unmarshal error: %v\n", err)
		return nil, err
	}

	// Fetch detailed info for each container to get the internal IP address
	for i, container := range containers {
		detailCmd := exec.Command("curl", "-s", "--unix-socket", "/var/run/docker.sock", fmt.Sprintf("http://localhost/containers/%s/json", container.ID))
		detailOutput, err := detailCmd.CombinedOutput()
		if err != nil {
			log.Printf("Curl command error for container %s: %s\n", container.ID, string(detailOutput))
			return nil, fmt.Errorf("error fetching details for container %s: %w", container.ID, err)
		}

		var detailedContainer DockerContainer
		if err := json.Unmarshal(detailOutput, &detailedContainer); err != nil {
			log.Printf("Unmarshal error for container %s: %v\n", container.ID, err)
			return nil, err
		}

		containers[i].NetworkSettings = detailedContainer.NetworkSettings
	}

	return containers, nil
}
