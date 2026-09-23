package learning

// Shared JSON helpers for the learning engine.
//
// core:encoding/json marshals map-based objects in unspecified key order, but
// event bytes must be stable for request deduplication and hashing. Documents
// that leave this process are therefore written by hand, in a fixed order,
// through the Obj builder below. Parsing still uses core:encoding/json.

import "core:encoding/json"
import "core:fmt"
import "core:strings"

// -- json.Value accessors (same shape as leetcode/api.odin) -------------------

jget :: proc(v: json.Value, key: string) -> json.Value {
	o, ok := v.(json.Object)
	if !ok { return nil }
	return o[key]
}
jstr :: proc(v: json.Value) -> string { return v.(string) or_else "" }
jint :: proc(v: json.Value) -> int {
	#partial switch n in v {
	case json.Integer: return int(n)
	case json.Float:   return int(n)
	}
	return 0
}
jbool :: proc(v: json.Value) -> bool { return v.(bool) or_else false }
jarray :: proc(v: json.Value) -> json.Array { return v.(json.Array) or_else nil }

// check_keys rejects unexpected input fields instead of quietly ignoring them
// (section 11: "Reject unexpected fields and invalid enums").
check_keys :: proc(v: json.Value, allowed, optional: []string) -> bool {
	o, is_obj := v.(json.Object)
	if !is_obj { return false }
	for key in o {
		ok := false
		for a in allowed { if a == key { ok = true; break } }
		if !ok {
			for a in optional { if a == key { ok = true; break } }
		}
		if !ok { return false }
	}
	return true
}

quote :: proc(s: string) -> string {
	// Marshaling a string value yields exactly one properly escaped JSON
	// string literal; reuse it instead of hand-rolling escaping.
	b, err := json.marshal(s)
	assert(err == nil, "string marshal")
	return string(b)
}

// -- ordered JSON object builder ----------------------------------------------

Obj :: struct {
	buf:  [dynamic]u8,
	first: bool,
}

obj_new :: proc() -> (o: Obj) { o.first = true; return }

obj_free :: proc(o: ^Obj) { delete(o.buf) }

// field_raw appends `"key":<raw>` where raw is pre-encoded JSON.
obj_field_raw :: proc(o: ^Obj, key, raw: string) {
	if !o.first { append(&o.buf, ',') }
	o.first = false
	append(&o.buf, '"')
	append(&o.buf, key)
	append(&o.buf, '"', ':')
	append(&o.buf, raw)
}

obj_field_str :: proc(o: ^Obj, key, s: string) { obj_field_raw(o, key, quote(s)) }

obj_field_int :: proc(o: ^Obj, key: string, i: int) {
	obj_field_raw(o, key, fmt.aprintf("%d", i))
}

obj_field_bool :: proc(o: ^Obj, key: string, b: bool) {
	obj_field_raw(o, key, "true" if b else "false")
}

// obj_field_strs writes a JSON string array. Arrays are emitted even when
// empty because the protocol schemas distinguish [] from a missing field.
obj_field_strs :: proc(o: ^Obj, key: string, items: []string) {
	if !o.first { append(&o.buf, ',') }
	o.first = false
	append(&o.buf, '"')
	append(&o.buf, key)
	append(&o.buf, '"', ':', '[')
	for item, i in items {
		if i > 0 { append(&o.buf, ',') }
		append(&o.buf, quote(item))
	}
	append(&o.buf, ']')
}

// obj_field_raws writes an array whose entries are already JSON encoded.
// This is used for arrays of objects; routing those values through
// obj_field_strs would turn each object into a quoted string.
obj_field_raws :: proc(o: ^Obj, key: string, items: []string) {
	if !o.first { append(&o.buf, ',') }
	o.first = false
	append(&o.buf, '"')
	append(&o.buf, key)
	append(&o.buf, '"', ':', '[')
	for item, i in items {
		if i > 0 { append(&o.buf, ',') }
		append(&o.buf, item)
	}
	append(&o.buf, ']')
}

obj_done :: proc(o: ^Obj) -> string {
	// Wrap the accumulated fields in braces and clone: string(o.buf[:])
	// aliases the buffer, so callers that free the builder (via defer)
	// would hand back dangling bytes.
	full := make([dynamic]u8, 0, len(o.buf) + 2)
	defer delete(full)
	append(&full, '{')
	append(&full, string(o.buf[:]))
	append(&full, '}')
	return strings.clone(string(full[:]))
}
