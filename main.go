package main
 
import (
    "encoding/json"
    "fmt"
    "log"
	"net/http"
	"io/ioutil"
	"os"
	
	"github.com/gorilla/mux"
	"github.com/google/uuid"
)

// Event model
type Event struct {
    ID     string `json:"id"`
    Title  string `json:"title"`
    Location string `json:"location"`
    When   string `json:"when"`
}
 
// Events array
var Events []Event
 
func home(w http.ResponseWriter, r *http.Request) {
    fmt.Fprintf(w, "Welcome to the Events API!")
    fmt.Println("Endpoint Hit: homeP")
}
 
func handleRequests() {
    myRouter := mux.NewRouter().StrictSlash(true)
    myRouter.HandleFunc("/", home)
	myRouter.HandleFunc("/events", getEvents).Methods("GET")
	myRouter.HandleFunc("/events/{id}",getEventbyID).Methods("GET")
	myRouter.HandleFunc("/events", createEvent).Methods("POST")
	myRouter.HandleFunc("/events/{id}", deleteEvent).Methods("DELETE")

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	fmt.Printf("Server running on Port: %s\n", port)
    log.Fatal(http.ListenAndServe(fmt.Sprintf(":%s", port), myRouter))
}
 
func getEvents(w http.ResponseWriter, r *http.Request) {
    fmt.Println("Endpoint Hit: getEvents")
    json.NewEncoder(w).Encode(Events)
}

func getEventbyID(w http.ResponseWriter, r *http.Request) {
	fmt.Println("Endpoint Hit: getEventbyID")
    vars := mux.Vars(r)
	key := vars["id"]
	
	fmt.Printf("Key: %s\n", key)
 
    for _, event := range Events {
        if event.ID == key {
            json.NewEncoder(w).Encode(event)
        }
    }
}

func createEvent(w http.ResponseWriter, r *http.Request) {
	fmt.Println("Endpoint Hit: createEvent")
	newID := uuid.New().String()
	fmt.Println(newID)
	
    reqBody, _ := ioutil.ReadAll(r.Body)
    var event Event 
	json.Unmarshal(reqBody, &event)
	event.ID = newID

    Events = append(Events, event)
 
    json.NewEncoder(w).Encode(event)
}

func deleteEvent(w http.ResponseWriter, r *http.Request) {
    vars := mux.Vars(r)
    id := vars["id"]
 
    for index, event := range Events {
        if event.ID == id {
            Events = append(Events[:index], Events[index+1:]...)
        }
    }
 
}

func main() {
    Events = []Event{
        Event{Title: "Dinner",
            Location: "My House",
			When:   "Tonight",
			ID: "2944a9cb-ef2d-4632-ac1d-af2b2629d0f2"},
        Event{Title: "Go Programming Lesson",
            Location: "At School",
			When:   "Tomorrow",
			ID: "f88f1860-9a5d-423e-820f-9acb4db3030e"},
		Event{Title: "Company Picnic",
            Location: "At the Park",
			When:   "Saturday",
			ID: "4cb393fb-dd19-469e-a52c-22a12c0a98df"},
	}
	
    handleRequests()
}