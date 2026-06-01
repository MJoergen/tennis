DUTS += tb_ball
DUTS += tb_collision_disk
DUTS += tb_collision_line
DUTS += tb_stats
DUTS += tb_tennis
DUTS += tb_unit_vector
DUTS += tb_wbus_stats

DUT_PASS   = $(patsubst %,%/PASS,$(DUTS))

all: $(DUT_PASS)

%/PASS: DUT=$(patsubst %/PASS,%,$@)
%/PASS:
	$(MAKE) -C $(DUT)

clean:
	for i in $(DUTS); do $(MAKE) -C $$i clean; done

