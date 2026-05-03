package main

/*
#include <stdlib.h>
*/
import "C"
import (
	"bytes"
	"encoding/json"
	"engine/backup"
	"engine/db"
	engineIO "engine/io"
	"engine/models"
	"fmt"
	"path/filepath"
	"strings"
	"sync"
	"unsafe"
)

var initMu sync.Mutex

var store *db.Store
var storageDir string // directory containing the DB file
var backupDir string  // directory where backup files are written

//export InitDB
func InitDB(path *C.char) *C.char {
	initMu.Lock()
	defer initMu.Unlock()
	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("InitDB panic recovered: %v\n", r)
		}
	}()

	p := C.GoString(path)
	storageDir = filepath.Dir(p)

	if store != nil {
		return C.CString("ok (already initialized)")
	}

	s, err := db.NewStore(p)
	if err != nil {
		return C.CString(fmt.Sprintf("error: %v", err))
	}
	store = s

	// Default backup dir to a "ContactsBackup" folder inside app documents
	if backupDir == "" {
		backupDir = filepath.Join(storageDir, "ContactsBackup")
	}

	return C.CString("ok")
}

// ─── Backup ──────────────────────────────────────────────────────────────────

//export SetBackupDir
func SetBackupDir(path *C.char) *C.char {
	initMu.Lock()
	defer initMu.Unlock()

	dir := C.GoString(path)
	if dir == "" {
		return C.CString("error: empty path")
	}
	backupDir = dir
	return C.CString("ok")
}

//export GetBackupDir
func GetBackupDir() *C.char {
	return C.CString(backupDir)
}

//export TriggerBackup
func TriggerBackup() *C.char {
	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("TriggerBackup panic recovered: %v\n", r)
		}
	}()

	if store == nil {
		return C.CString("error: store not initialized")
	}
	if backupDir == "" {
		return C.CString("error: backup directory not set")
	}

	meta, err := backup.WriteBackup(store, backupDir)
	if err != nil {
		return C.CString(fmt.Sprintf("error: %v", err))
	}

	data, _ := json.Marshal(meta)
	return C.CString(string(data))
}

//export RestoreFromBackup
func RestoreFromBackup(path *C.char) *C.char {
	initMu.Lock()
	defer initMu.Unlock()
	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("RestoreFromBackup panic recovered: %v\n", r)
		}
	}()

	if store == nil {
		return C.CString("error: store not initialized")
	}

	count, err := backup.RestoreBackup(store, C.GoString(path))
	if err != nil {
		return C.CString(fmt.Sprintf("error: %v", err))
	}
	return C.CString(fmt.Sprintf("restored %d contacts", count))
}

//export GetBackupStatus
func GetBackupStatus() *C.char {
	meta := backup.GetLastMeta()
	data, _ := json.Marshal(meta)
	return C.CString(string(data))
}

// ─── Contacts CRUD ───────────────────────────────────────────────────────────

//export ListContacts
func ListContacts() *C.char {
	if store == nil {
		return C.CString("[]")
	}
	contacts, err := store.ListContacts()
	if err != nil {
		return C.CString("[]")
	}
	data, _ := json.Marshal(contacts)
	return C.CString(string(data))
}

//export SaveContact
func SaveContact(jsonStr *C.char) *C.char {
	initMu.Lock()
	defer initMu.Unlock()
	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("SaveContact panic recovered: %v\n", r)
		}
	}()

	if store == nil {
		return C.CString("error: store not initialized")
	}
	var c models.Contact
	if err := json.Unmarshal([]byte(C.GoString(jsonStr)), &c); err != nil {
		return C.CString(fmt.Sprintf("error: %v", err))
	}
	if err := store.SaveContact(c); err != nil {
		return C.CString(fmt.Sprintf("error: %v", err))
	}

	// Auto-backup after every contact save
	if backupDir != "" {
		go backup.WriteBackup(store, backupDir)
	}

	return C.CString("ok")
}

//export DeleteContact
func DeleteContact(id *C.char) *C.char {
	initMu.Lock()
	defer initMu.Unlock()
	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("DeleteContact panic recovered: %v\n", r)
		}
	}()

	if store == nil {
		return C.CString("error: store not initialized")
	}
	if err := store.DeleteContact(C.GoString(id)); err != nil {
		return C.CString(fmt.Sprintf("error: %v", err))
	}

	// Auto-backup after every contact delete
	if backupDir != "" {
		go backup.WriteBackup(store, backupDir)
	}

	return C.CString("ok")
}

//export SearchContacts
func SearchContacts(query *C.char) *C.char {
	if store == nil {
		return C.CString("[]")
	}
	contacts, err := store.SearchContacts(C.GoString(query))
	if err != nil {
		return C.CString("[]")
	}
	data, _ := json.Marshal(contacts)
	return C.CString(string(data))
}

// ─── Import/Export ───────────────────────────────────────────────────────────

//export ImportFromFile
func ImportFromFile(data *C.char, format *C.char) *C.char {
	if store == nil {
		return C.CString("error: store not initialized")
	}
	d := C.GoString(data)
	f := C.GoString(format)
	var contacts []models.Contact
	var err error

	r := strings.NewReader(d)
	switch f {
	case "vcf":
		contacts, err = engineIO.ImportFromVCF(r)
	case "csv":
		contacts, err = engineIO.ImportFromCSV(r)
	case "ldif":
		contacts, err = engineIO.ImportFromLDIF(r)
	default:
		return C.CString("error: unsupported format")
	}

	if err != nil {
		return C.CString(fmt.Sprintf("error: %v", err))
	}

	count := 0
	for _, c := range contacts {
		if err := store.SaveContact(c); err == nil {
			count++
		}
	}

	// Auto-backup after import
	if backupDir != "" {
		go backup.WriteBackup(store, backupDir)
	}

	return C.CString(fmt.Sprintf("imported %d contacts", count))
}

//export ExportToFile
func ExportToFile(format *C.char) *C.char {
	if store == nil {
		return C.CString("")
	}
	f := C.GoString(format)
	contacts, err := store.ListContacts()
	if err != nil {
		return C.CString("")
	}

	var buf bytes.Buffer
	switch f {
	case "vcf":
		err = engineIO.ExportToVCF(contacts, &buf)
	case "csv":
		err = engineIO.ExportToCSV(contacts, &buf)
	case "md":
		err = engineIO.ExportToMarkdown(contacts, &buf)
	default:
		return C.CString("")
	}

	if err != nil {
		return C.CString("")
	}
	return C.CString(buf.String())
}

//export FreeString
func FreeString(s *C.char) {
	C.free(unsafe.Pointer(s))
}

func main() {}
