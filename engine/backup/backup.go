package backup

import (
	"encoding/json"
	"engine/db"
	"engine/models"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"
)

const backupFileName = "contacts_backup.json"

// BackupMeta holds metadata about the last backup.
type BackupMeta struct {
	LastBackupTime int64  `json:"last_backup_time"`
	ContactCount   int    `json:"contact_count"`
	BackupPath     string `json:"backup_path"`
}

// BackupFile is the structure written to disk.
type BackupFile struct {
	Version    int              `json:"version"`
	ExportedAt int64            `json:"exported_at"`
	Contacts   []models.Contact `json:"contacts"`
}

var (
	mu       sync.Mutex
	lastMeta BackupMeta
)

// WriteBackup exports all contacts from the store as a JSON file into dir.
// Uses atomic write (tmp file + rename) to prevent corruption.
func WriteBackup(store *db.Store, dir string) (BackupMeta, error) {
	mu.Lock()
	defer mu.Unlock()

	if store == nil {
		return BackupMeta{}, fmt.Errorf("store is nil")
	}
	if dir == "" {
		return BackupMeta{}, fmt.Errorf("backup directory not set")
	}

	// Ensure directory exists
	if err := os.MkdirAll(dir, 0755); err != nil {
		return BackupMeta{}, fmt.Errorf("creating backup dir: %w", err)
	}

	contacts, err := store.ListContacts()
	if err != nil {
		return BackupMeta{}, fmt.Errorf("listing contacts: %w", err)
	}

	now := time.Now().Unix()
	bf := BackupFile{
		Version:    1,
		ExportedAt: now,
		Contacts:   contacts,
	}

	data, err := json.MarshalIndent(bf, "", "  ")
	if err != nil {
		return BackupMeta{}, fmt.Errorf("marshaling backup: %w", err)
	}

	targetPath := filepath.Join(dir, backupFileName)
	tmpPath := targetPath + ".tmp"

	// Atomic write: write to tmp, then rename
	if err := os.WriteFile(tmpPath, data, 0644); err != nil {
		return BackupMeta{}, fmt.Errorf("writing tmp file: %w", err)
	}
	if err := os.Rename(tmpPath, targetPath); err != nil {
		// Fallback: try direct write
		os.Remove(tmpPath)
		if err := os.WriteFile(targetPath, data, 0644); err != nil {
			return BackupMeta{}, fmt.Errorf("writing backup file: %w", err)
		}
	}

	lastMeta = BackupMeta{
		LastBackupTime: now,
		ContactCount:   len(contacts),
		BackupPath:     targetPath,
	}

	return lastMeta, nil
}

// ReadBackup reads and parses a backup JSON file, returning the contacts.
func ReadBackup(path string) ([]models.Contact, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("reading backup file: %w", err)
	}

	var bf BackupFile
	if err := json.Unmarshal(data, &bf); err != nil {
		return nil, fmt.Errorf("parsing backup file: %w", err)
	}

	return bf.Contacts, nil
}

// RestoreBackup reads contacts from a backup file and imports them into the store.
func RestoreBackup(store *db.Store, path string) (int, error) {
	contacts, err := ReadBackup(path)
	if err != nil {
		return 0, err
	}

	count := 0
	for _, c := range contacts {
		if err := store.SaveContact(c); err == nil {
			count++
		}
	}
	return count, nil
}

// GetLastMeta returns metadata about the most recent backup.
func GetLastMeta() BackupMeta {
	mu.Lock()
	defer mu.Unlock()
	return lastMeta
}
