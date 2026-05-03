package io

import (
	"bytes"
	"encoding/csv"
	"engine/models"
	"fmt"
	"io"
	"strings"

	"github.com/emersion/go-vcard"
	"github.com/gocarina/gocsv"
	"github.com/go-ldap/ldif"
)

// ImportFromVCF parses vCard data into a slice of contacts.
func ImportFromVCF(r io.Reader) ([]models.Contact, error) {
	dec := vcard.NewDecoder(r)
	var contacts []models.Contact
	for {
		card, err := dec.Decode()
		if err == io.EOF {
			break
		} else if err != nil {
			return nil, err
		}

		c := models.Contact{
			ID:       strings.TrimPrefix(card.Value(vcard.FieldUID), "urn:uuid:"),
			Nickname: card.Value(vcard.FieldNickname),
			Phone:    card.Value(vcard.FieldTelephone),
			Email:    card.Value(vcard.FieldEmail),
			Note:     card.Value(vcard.FieldNote),
		}
		name := card.Name()
		if name != nil {
			c.FirstName = name.GivenName
			c.LastName = name.FamilyName
		}
		if c.ID == "" {
			c.ID = fmt.Sprintf("%d", len(contacts)+1)
		}
		contacts = append(contacts, c)
	}
	return contacts, nil
}

// ExportToVCF encodes contacts into vCard format.
// FormattedName (FN) is required by vCard 3.0 spec.
func ExportToVCF(contacts []models.Contact, w io.Writer) error {
	enc := vcard.NewEncoder(w)
	for _, c := range contacts {
		card := make(vcard.Card)
		card.SetValue(vcard.FieldVersion, "3.0")
		card.AddValue(vcard.FieldUID, c.ID)
		card.SetName(&vcard.Name{
			GivenName:  c.FirstName,
			FamilyName: c.LastName,
		})
		fullName := strings.TrimSpace(c.FirstName + " " + c.LastName)
		if fullName == "" {
			fullName = c.Nickname
		}
		card.SetValue(vcard.FieldFormattedName, fullName)
		if c.Nickname != "" {
			card.AddValue(vcard.FieldNickname, c.Nickname)
		}
		if c.Phone != "" {
			card.AddValue(vcard.FieldTelephone, c.Phone)
		}
		if c.Email != "" {
			card.AddValue(vcard.FieldEmail, c.Email)
		}
		if c.Note != "" {
			card.AddValue(vcard.FieldNote, c.Note)
		}
		if err := enc.Encode(card); err != nil {
			return err
		}
	}
	return nil
}

// normalizeCSVHeader maps common CSV column name variants to gocsv struct tag names.
func normalizeCSVHeader(h string) string {
	h = strings.ToLower(strings.TrimSpace(h))
	h = strings.ReplaceAll(h, " ", "_")
	h = strings.ReplaceAll(h, "-", "_")
	// Strip BOM and quotes
	h = strings.Trim(h, "\"\uFEFF")
	switch h {
	case "firstname", "given_name", "givenname", "first":
		return "first_name"
	case "lastname", "family_name", "familyname", "surname", "last":
		return "last_name"
	case "phone", "telephone", "phone_number", "phonenumber", "mobile", "cell", "tel":
		return "phone"
	case "e_mail", "e-mail", "mail", "emailaddress", "email_address":
		return "email"
	case "org", "company", "organisation", "organization_name":
		return "organization"
	case "notes", "comment", "comments", "description":
		return "note"
	case "uid", "contact_id", "contactid":
		return "id"
	case "nick", "alias":
		return "nickname"
	}
	return h
}

// ImportFromCSV parses CSV data into a slice of contacts.
// Handles column name variations from Google Contacts, iPhone, Outlook exports, etc.
func ImportFromCSV(r io.Reader) ([]models.Contact, error) {
	cr := csv.NewReader(r)
	cr.LazyQuotes = true
	cr.TrimLeadingSpace = true

	header, err := cr.Read()
	if err != nil {
		return nil, fmt.Errorf("reading CSV header: %w", err)
	}

	// Normalize headers to match gocsv struct tags
	for i, h := range header {
		header[i] = normalizeCSVHeader(h)
	}

	// Re-assemble normalized CSV into a buffer for gocsv
	var buf bytes.Buffer
	w := csv.NewWriter(&buf)
	if err := w.Write(header); err != nil {
		return nil, err
	}
	for {
		row, err := cr.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, err
		}
		if err := w.Write(row); err != nil {
			return nil, err
		}
	}
	w.Flush()

	var contacts []models.Contact
	if err := gocsv.UnmarshalBytes(buf.Bytes(), &contacts); err != nil {
		return nil, err
	}
	return contacts, nil
}

// ExportToCSV encodes contacts into CSV format.
func ExportToCSV(contacts []models.Contact, w io.Writer) error {
	return gocsv.Marshal(contacts, w)
}

// ExportToMarkdown generates a markdown table for contacts.
func ExportToMarkdown(contacts []models.Contact, w io.Writer) error {
	fmt.Fprintln(w, "# Contacts List")
	fmt.Fprintln(w)
	fmt.Fprintln(w, "| Name | Phone | Email | Organization | Note |")
	fmt.Fprintln(w, "| --- | --- | --- | --- | --- |")
	for _, c := range contacts {
		fmt.Fprintf(w, "| %s %s | %s | %s | %s | %s |\n",
			c.FirstName, c.LastName, c.Phone, c.Email, c.Organization, c.Note)
	}
	return nil
}

// ImportFromLDIF is a simplified LDIF parser.
func ImportFromLDIF(r io.Reader) ([]models.Contact, error) {
	var l ldif.LDIF
	if err := ldif.Unmarshal(r, &l); err != nil {
		return nil, err
	}
	var contacts []models.Contact
	for _, entry := range l.Entries {
		if entry.Entry != nil {
			c := models.Contact{
				ID:           entry.Entry.DN,
				FirstName:    entry.Entry.GetAttributeValue("givenName"),
				LastName:     entry.Entry.GetAttributeValue("sn"),
				Phone:        entry.Entry.GetAttributeValue("telephoneNumber"),
				Email:        entry.Entry.GetAttributeValue("mail"),
				Organization: entry.Entry.GetAttributeValue("o"),
			}
			contacts = append(contacts, c)
		}
	}
	return contacts, nil
}
