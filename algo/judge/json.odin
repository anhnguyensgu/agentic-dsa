package judge

import "core:encoding/json"
import "core:fmt"
import "core:strconv"

// Judge APIs are proxied and reshaped freely, so their responses stay dynamic
// json.Values. These accessors return zero values for missing or mistyped
// fields; callers validate the fields they depend on.

jget :: proc(v: json.Value, key: string) -> json.Value {
	o := v.(json.Object) or_else nil
	return o[key]
}

jstr :: proc(v: json.Value) -> string {
	return v.(string) or_else ""
}

// jint also accepts numeric strings, which judges use for some ids.
jint :: proc(v: json.Value) -> int {
	#partial switch n in v {
	case json.Integer: return int(n)
	case json.Float:   return int(n)
	case string:       return strconv.parse_int(n) or_else 0
	}
	return 0
}

jbool :: proc(v: json.Value) -> bool {
	return v.(bool) or_else false
}

jarray :: proc(v: json.Value) -> json.Array {
	return v.(json.Array) or_else nil
}

jobject :: proc() -> json.Object {
	return make(json.Object)
}

encode_json :: proc(v: any) -> string {
	data, err := json.marshal(v)
	assert(err == nil, "values built by this program must be marshalable")
	return string(data)
}

// print_json writes a report to stdout; diagnostics go to stderr.
print_json :: proc(v: any) {
	fmt.println(encode_json(v))
}
