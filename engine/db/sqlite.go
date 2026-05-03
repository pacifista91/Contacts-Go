package db

import (
	"database/sql"
	"engine/models"

	"strings"

	_ "modernc.org/sqlite"
)

type Store struct {
	db *sql.DB
}

func NewStore(path string) (*Store, error) {
	db, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, err
	}
	if err := db.Ping(); err != nil {
		return nil, err
	}
	// Increase busy timeout for better concurrency handling
	if _, err := db.Exec(`PRAGMA busy_timeout = 5000`); err != nil {
		return nil, err
	}
	if _, err := db.Exec(`CREATE TABLE IF NOT EXISTS contacts (
		id TEXT PRIMARY KEY,
		first_name TEXT,
		last_name TEXT,
		nickname TEXT,
		phone TEXT,
		email TEXT,
		organization TEXT,
		note TEXT,
		is_favorite INTEGER DEFAULT 0,
		updated_at INTEGER
	)`); err != nil {
		return nil, err
	}

	// Migration: add is_favorite column if it doesn't exist
	db.Exec(`ALTER TABLE contacts ADD COLUMN is_favorite INTEGER DEFAULT 0`)

	return &Store{db: db}, nil
}

// ─── Contacts CRUD ───────────────────────────────────────────────────────────

func (s *Store) SaveContact(c models.Contact) error {
	isFav := 0
	if c.IsFavorite {
		isFav = 1
	}
	_, err := s.db.Exec(`INSERT INTO contacts (id, first_name, last_name, nickname, phone, email, organization, note, is_favorite, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(id) DO UPDATE SET
			first_name=excluded.first_name,
			last_name=excluded.last_name,
			nickname=excluded.nickname,
			phone=excluded.phone,
			email=excluded.email,
			organization=excluded.organization,
			note=excluded.note,
			is_favorite=excluded.is_favorite,
			updated_at=excluded.updated_at`,
		c.ID, c.FirstName, c.LastName, c.Nickname, c.Phone, c.Email, c.Organization, c.Note, isFav, c.UpdatedAt)
	return err
}

func (s *Store) DeleteContact(id string) error {
	_, err := s.db.Exec("DELETE FROM contacts WHERE id=?", id)
	return err
}

func (s *Store) ListContacts() ([]models.Contact, error) {
	rows, err := s.db.Query("SELECT id, first_name, last_name, nickname, phone, email, organization, note, COALESCE(is_favorite, 0), updated_at FROM contacts ORDER BY first_name ASC")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var contacts []models.Contact
	for rows.Next() {
		var c models.Contact
		var isFav int
		if err := rows.Scan(&c.ID, &c.FirstName, &c.LastName, &c.Nickname, &c.Phone, &c.Email, &c.Organization, &c.Note, &isFav, &c.UpdatedAt); err != nil {
			return nil, err
		}
		c.IsFavorite = isFav == 1
		contacts = append(contacts, c)
	}
	return contacts, nil
}

func (s *Store) SearchContacts(query string) ([]models.Contact, error) {
	q := "%" + strings.ToLower(query) + "%"
	rows, err := s.db.Query(`SELECT id, first_name, last_name, nickname, phone, email, organization, note, COALESCE(is_favorite, 0), updated_at FROM contacts 
		WHERE LOWER(first_name) LIKE ? OR LOWER(last_name) LIKE ? OR phone LIKE ? OR LOWER(email) LIKE ? OR LOWER(organization) LIKE ? OR LOWER(nickname) LIKE ?
		ORDER BY first_name ASC`, q, q, q, q, q, q)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var contacts []models.Contact
	for rows.Next() {
		var c models.Contact
		var isFav int
		if err := rows.Scan(&c.ID, &c.FirstName, &c.LastName, &c.Nickname, &c.Phone, &c.Email, &c.Organization, &c.Note, &isFav, &c.UpdatedAt); err != nil {
			return nil, err
		}
		c.IsFavorite = isFav == 1
		contacts = append(contacts, c)
	}
	return contacts, nil
}

func (s *Store) GetContact(id string) (*models.Contact, error) {
	row := s.db.QueryRow("SELECT id, first_name, last_name, nickname, phone, email, organization, note, COALESCE(is_favorite, 0), updated_at FROM contacts WHERE id=?", id)
	var c models.Contact
	var isFav int
	if err := row.Scan(&c.ID, &c.FirstName, &c.LastName, &c.Nickname, &c.Phone, &c.Email, &c.Organization, &c.Note, &isFav, &c.UpdatedAt); err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	c.IsFavorite = isFav == 1
	return &c, nil
}

func (s *Store) Close() error {
	return s.db.Close()
}
