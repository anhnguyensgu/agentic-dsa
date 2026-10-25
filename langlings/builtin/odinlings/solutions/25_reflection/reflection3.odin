// reflection3.odin
package main

import "core:encoding/json"
import "core:reflect"
import "core:testing"

User :: struct {
	name:     string `json:"user_name"`,
	age:      int,
	password: string `json:"-"`,
}

json_field_names :: proc($T: typeid) -> []string {
	names := make([dynamic]string, context.temp_allocator)
	fields := reflect.struct_field_names(T)
	tags := reflect.struct_field_tags(T)
	for name, i in fields {
		tag := reflect.struct_tag_get(tags[i], "json")
		switch tag {
		case "-":
			continue
		case "":
			append(&names, name)
		case:
			append(&names, tag)
		}
	}
	return names[:]
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_marshal :: proc(t: ^testing.T) {
	data, err := json.marshal(User{"Ada", 36, "hunter2"}, allocator = context.temp_allocator)
	testing.expect_value(t, err, nil)
	testing.expect_value(t, string(data), `{"user_name":"Ada","age":36}`)
}

@(test)
test_json_field_names :: proc(t: ^testing.T) {
	names := json_field_names(User)
	testing.expect_value(t, len(names), 2)
	if len(names) == 2 {
		testing.expect_value(t, names[0], "user_name")
		testing.expect_value(t, names[1], "age")
	}
}
