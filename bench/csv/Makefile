ODIN_FLAGS := -vet -strict-style
ROWS ?= 15000000
RUNS ?= 5
CSV := data/sales.csv

.PHONY: all build data bench test check clean

all: bench

build: bin/gen bin/reader

bin/gen: gen/*.odin
	@mkdir -p bin
	odin build gen -out:$@ -o:speed $(ODIN_FLAGS)

# -microarch:native: the SIMD steps use 64-byte vectors (AVX-512 where available).
bin/reader: reader/*.odin
	@mkdir -p bin
	odin build reader -out:$@ -o:speed -microarch:native $(ODIN_FLAGS)

$(CSV): bin/gen
	@mkdir -p data
	./bin/gen $@ $(ROWS)

data: $(CSV)

bench: bin/reader $(CSV)
	./bin/reader $(CSV) -runs:$(RUNS)

test: build
	sh test/run.sh

check:
	odin check gen $(ODIN_FLAGS)
	odin check reader $(ODIN_FLAGS)

clean:
	rm -rf bin data
