# List of source files
SRC += $(SRC_DIR)/collision_disk.vhd
SRC += $(SRC_DIR)/math/adder.vhd
SRC += $(SRC_DIR)/math/cordic_rotate.vhd
SRC += $(SRC_DIR)/math/dot_product.vhd
SRC += $(SRC_DIR)/math/scalar_product.vhd
SRC += $(SRC_DIR)/math/shifter.vhd
SRC += $(SRC_DIR)/math/unit_vector.vhd

# List of test specific simulation files
SRC += tb_collision_disk.vhd

# Top level entity
DUT = collision_disk

# Test duration
STOP_TIME = 30us

# Don't stop on errors
#ASSERT_LEVEL = none

include ../Makefile.inc

