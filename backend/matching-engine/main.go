package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"math"
	"os"
	"sort"
)

type DriverInput struct {
	ID               string  `json:"id"`
	Lat              float64 `json:"lat"`
	Lng              float64 `json:"lng"`
	Rating           float64 `json:"rating"`
	AcceptanceRate   float64 `json:"acceptanceRate"`
	CancellationRate float64 `json:"cancellationRate"`
	VehicleType      string  `json:"vehicleType"`
}

type MatchRequest struct {
	Action    string        `json:"action"`
	PickupLat float64       `json:"pickupLat"`
	PickupLng float64       `json:"pickupLng"`
	Drivers   []DriverInput `json:"drivers"`
}

type DriverOutput struct {
	ID       string  `json:"id"`
	Lat      float64 `json:"lat"`
	Lng      float64 `json:"lng"`
	Score    float64 `json:"score"`
	Distance float64 `json:"distance"`
	ETA      float64 `json:"eta"` // in minutes
}

type MatchResponse struct {
	Status  string         `json:"status"`
	Results []DriverOutput `json:"results"`
	Error   string         `json:"error,omitempty"`
}

// haversine calculates distance between two points in km
func haversine(lat1, lon1, lat2, lon2 float64) float64 {
	const R = 6371.0
	dLat := (lat2 - lat1) * math.Pi / 180.0
	dLon := (lon2 - lon1) * math.Pi / 180.0
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*math.Pi/180.0)*math.Cos(lat2*math.Pi/180.0)*
		math.Sin(dLon/2)*math.Sin(dLon/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
	return R * c
}

func scoreDriver(driver DriverInput, pickupLat, pickupLng float64) DriverOutput {
	distance := haversine(pickupLat, pickupLng, driver.Lat, driver.Lng)

	// Assume average speed is 30 km/h (0.5 km/min).
	// So ETA = distance / 0.5 = distance * 2.
	etaMinutes := distance * 2.0
	if etaMinutes < 1.0 {
		etaMinutes = 1.0 // minimum 1 min
	}

	etaScore := 1.0 / (1.0 + etaMinutes)
	ratingScore := driver.Rating / 5.0
	acceptanceScore := driver.AcceptanceRate
	cancellationScore := 1.0 - driver.CancellationRate

	// PRD Algorithm: score = (0.40 * eta_score) + (0.25 * rating_score) + (0.20 * acceptance_score) + (0.15 * cancellation_score)
	score := (0.40 * etaScore) + (0.25 * ratingScore) + (0.20 * acceptanceScore) + (0.15 * cancellationScore)

	return DriverOutput{
		ID:       driver.ID,
		Lat:      driver.Lat,
		Lng:      driver.Lng,
		Score:    score,
		Distance: distance,
		ETA:      etaMinutes,
	}
}

func main() {
	scanner := bufio.NewScanner(os.Stdin)
	for scanner.Scan() {
		line := scanner.Bytes()
		if len(line) == 0 {
			continue
		}

		var req MatchRequest
		if err := json.Unmarshal(line, &req); err != nil {
			sendError(fmt.Sprintf("Failed to parse request: %v", err))
			continue
		}

		if req.Action != "score_drivers" {
			sendError(fmt.Sprintf("Unknown action: %s", req.Action))
			continue
		}

		results := make([]DriverOutput, 0, len(req.Drivers))
		for _, driver := range req.Drivers {
			scored := scoreDriver(driver, req.PickupLat, req.PickupLng)
			results = append(results, scored)
		}

		// Sort by score descending
		sort.Slice(results, func(i, j int) bool {
			return results[i].Score > results[j].Score
		})

		// Limit to top 3
		if len(results) > 3 {
			results = results[:3]
		}

		response := MatchResponse{
			Status:  "success",
			Results: results,
		}

		resBytes, _ := json.Marshal(response)
		fmt.Println(string(resBytes))
	}
}

func sendError(msg string) {
	resp := MatchResponse{
		Status: "error",
		Error:  msg,
	}
	resBytes, _ := json.Marshal(resp)
	fmt.Println(string(resBytes))
}
