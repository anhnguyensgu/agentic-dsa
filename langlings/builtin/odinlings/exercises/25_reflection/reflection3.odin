// reflection3.odin
//
// Field tags are strings attached to struct fields. `core:encoding/json`
// reads the `json` key: `json:"other_name"` renames a field, and `json:"-"`
// leaves it out.
package main

import "core:encoding/json"
import "core:reflect"
import "core:testing"

User :: struct {
	// TODO: Tag the fields so the JSON matches the test: `name` is written
	// as "user_name", `age` keeps its name, and `password` is left out.
	name:     string,
	age:      int,
	password: string,
}

// The JSON names of T's fields, in order, using the same rules as above.
// Returns a slice allocated with the temp allocator.
json_field_names :: proc($T: typeid) -> []string {
	names := make([dynamic]string, context.temp_allocator)
	fields := reflect.struct_field_names(T)
	tags := reflect.struct_field_tags(T)
	for name, i in fields {
		// TODO: Use `reflect.struct_tag_get(tags[i], "json")`: skip "-", use
		// the tag when there is one, and the field name otherwise.
		_ = tags[i]
		append(&names, name)
	}
	return names[:]
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

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
