package learning

// JSON at the engine boundary. Documents are typed structs marshaled with
// core:encoding/json, which writes struct fields in declaration order, so
// event and envelope bytes are stable.
//
// Raw_JSON holds an already-encoded document (an event payload, a nested
// report). It is written verbatim, and decoded into a canonical encoding with
// sorted keys, so two equal payloads always compare equal as strings.

import "base:runtime"
import "core:encoding/json"
import "core:io"
import "core:strings"

Raw_JSON :: distinct string

EMPTY_OBJECT :: Raw_JSON("{}")

@(private = "file")
user_marshalers: map[typeid]json.User_Marshaler
@(private = "file")
user_unmarshalers: map[typeid]json.User_Unmarshaler

@(init, private = "file")
register_raw_json :: proc "contextless" () {
	context = runtime.default_context()
	json.set_user_marshalers(&user_marshalers)
	json.set_user_unmarshalers(&user_unmarshalers)
	json.register_user_marshaler(Raw_JSON, marshal_raw)
	json.register_user_unmarshaler(Raw_JSON, unmarshal_raw)
}

@(private = "file")
marshal_raw :: proc(w: io.Writer, v: any, opt: ^json.Marshal_Options) -> json.Marshal_Error {
	raw := (^Raw_JSON)(v.data)^
	_, err := io.write_string(w, string(raw) if raw != "" else "null")
	return err
}

@(private = "file")
unmarshal_raw :: proc(p: ^json.Parser, v: any) -> json.Unmarshal_Error {
	value := json.parse_value(p) or_return
	data, err := json.marshal(value, {sort_maps_by_key = true})
	if err != nil {
		return .Invalid_Data
	}
	(^Raw_JSON)(v.data)^ = Raw_JSON(data)
	return nil
}

// to_json encodes a value the engine built itself; failure is a programming error.
to_json :: proc(v: any) -> Raw_JSON {
	data, err := json.marshal(v)
	assert(err == nil, "engine documents must be marshalable")
	return Raw_JSON(data)
}

// decode parses text into a typed document. Unknown fields are ignored;
// callers that must reject them check the keys first. The text is validated
// first because unmarshal asserts, rather than failing, on malformed input.
decode :: proc(text: string, v: ^$T) -> bool {
	return json.is_valid(transmute([]byte)text, .JSON, parse_integers = true) && json.unmarshal_string(text, v, .JSON) == nil
}

// Dynamic accessors for documents without a fixed shape, such as provider
// adapter output. They yield zero values for missing or mistyped fields.

jget :: proc(v: json.Value, key: string) -> json.Value {
	o, ok := v.(json.Object)
	return o[key] if ok else nil
}

jstr :: proc(v: json.Value) -> string {
	return v.(string) or_else ""
}

jint :: proc(v: json.Value) -> int {
	#partial switch n in v {
	case json.Integer: return int(n)
	case json.Float:   return int(n)
	}
	return 0
}

parse_json :: proc(text: string) -> (json.Value, bool) {
	v, err := json.parse_string(strings.trim_space(text), .JSON, parse_integers = true)
	return v, err == nil
}

// parse_enum maps a wire name to its enum value using the enum's name table.
parse_enum :: proc(names: [$E]string, s: string) -> (E, bool) {
	for name, e in names {
		if name == s {
			return e, true
		}
	}
	return {}, false
}

contains :: proc(values: []string, needle: string) -> bool {
	for v in values {
		if v == needle {
			return true
		}
	}
	return false
}
