// structs2.odin
package main

import "core:testing"

Order :: struct {
	name:          string,
	year:          int,
	made_by_phone: bool,
	made_by_email: bool,
	item_number:   int,
	count:         int,
}

order_template :: proc() -> Order {
	return Order{name = "Bob", year = 2019, made_by_email = true, item_number = 123}
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_your_order :: proc(t: ^testing.T) {
	template := order_template()

	// Assigning a struct copies it, so changing the copy leaves the template
	// alone.
	your_order := template
	your_order.name = "Hacker"
	your_order.count = 1

	testing.expect_value(t, your_order.name, "Hacker")
	testing.expect_value(t, your_order.year, 2019)
	testing.expect_value(t, your_order.made_by_phone, false)
	testing.expect_value(t, your_order.made_by_email, true)
	testing.expect_value(t, your_order.item_number, 123)
	testing.expect_value(t, your_order.count, 1)

	testing.expect_value(t, template.name, "Bob")
}
