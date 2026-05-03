package models

type Contact struct {
	ID           string `json:"id" gocsv:"id"`
	FirstName    string `json:"first_name" gocsv:"first_name"`
	LastName     string `json:"last_name" gocsv:"last_name"`
	Nickname     string `json:"nickname" gocsv:"nickname"`
	Phone        string `json:"phone" gocsv:"phone"`
	Email        string `json:"email" gocsv:"email"`
	Organization string `json:"organization" gocsv:"organization"`
	Note         string `json:"note" gocsv:"note"`
	IsFavorite   bool   `json:"is_favorite" gocsv:"is_favorite"`
	UpdatedAt    int64  `json:"updated_at" gocsv:"updated_at"`
}
