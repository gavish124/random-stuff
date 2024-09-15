#!/bin/bash

# GPU PCI address and IDs (update with your GPU's address and IDs)
GPU_PCI_ADDRESS="0000:00:02.0"
VENDOR_ID="8086"
DEVICE_ID="5917"

# Path to the VFIO driver
VFIO_DRIVER="/sys/bus/pci/drivers/vfio-pci"
# Path to the i915 driver
I915_DRIVER="/sys/bus/pci/drivers/i915"

# Function to check if GPU is bound to vfio-pci
is_gpu_bound_to_vfio() {
    [ -e "$VFIO_DRIVER/$GPU_PCI_ADDRESS" ]
}

# Function to check if GPU is bound to i915
is_gpu_bound_to_i915() {
    [ -e "$I915_DRIVER/$GPU_PCI_ADDRESS" ]
}

# Function to load kernel module
load_module() {
    local module=$1
    if ! lsmod | grep -q "$module"; then
        echo "Loading $module module..."
        sudo modprobe "$module"
    else
        echo "$module module is already loaded."
    fi
}

# Function to unbind GPU from the i915 driver
unbind_gpu_from_i915() {
    echo "Unbinding GPU from i915 driver..."
    if is_gpu_bound_to_i915; then
        echo "$GPU_PCI_ADDRESS" | sudo tee "$I915_DRIVER/unbind" > /dev/null
        sleep 2
        if ! is_gpu_bound_to_i915; then
            echo "GPU successfully unbound from i915 driver."
        else
            echo "Error: GPU still bound to i915 driver."
            exit 1
        fi
    else
        echo "GPU is not bound to i915 driver. Skipping unbind step."
    fi
}

# Function to bind GPU to the VFIO driver
bind_gpu_to_vfio() {
    echo "Binding GPU to VFIO driver..."
    # Load vfio-pci module
    load_module vfio-pci

    # Add device ID to vfio-pci
    echo "$VENDOR_ID $DEVICE_ID" | sudo tee "$VFIO_DRIVER/new_id" > /dev/null

    # Unbind from any other driver if necessary
    if is_gpu_bound_to_vfio; then
        echo "GPU is already bound to VFIO driver."
    else
        echo "$GPU_PCI_ADDRESS" | sudo tee "$VFIO_DRIVER/bind" > /dev/null
        sleep 2
        if is_gpu_bound_to_vfio; then
            echo "GPU successfully bound to VFIO driver."
        else
            echo "Error: GPU could not be bound to VFIO driver. Ensure vfio-pci module is loaded and GPU is available."
            echo "Attempting manual binding..."
            # Manual binding attempt
            echo "$GPU_PCI_ADDRESS" | sudo tee "$VFIO_DRIVER/bind"
            echo "$VENDOR_ID $DEVICE_ID" | sudo tee "$VFIO_DRIVER/new_id"
            exit 1
        fi
    fi
}

# Function to rebind GPU to the i915 driver
rebind_gpu_to_i915() {
    echo "Rebinding GPU to i915 driver..."
    if is_gpu_bound_to_i915; then
        echo "GPU is already bound to i915 driver."
    else
        echo "$GPU_PCI_ADDRESS" | sudo tee "$I915_DRIVER/bind" > /dev/null
        sleep 2
        if is_gpu_bound_to_i915; then
            echo "GPU successfully rebound to i915 driver."
        else
            echo "Error: GPU could not be rebound to i915 driver. It might still be in use or there may be a conflict."
            exit 1
        fi
    fi
}

# Function to start macOS VM using an external script
start_macos_vm() {
    echo "Starting macOS VM..."
    if [ -f "./opencore-boot-pt.sh" ]; then
        ./opencore-boot-pt.sh
    else
        echo "Error: opencore-boot-pt.sh not found."
        exit 1
    fi
}

# Main script
unbind_gpu_from_i915
bind_gpu_to_vfio

# Check if GPU is bound to VFIO before starting the VM
if is_gpu_bound_to_vfio; then
    start_macos_vm
else
    echo "Error: GPU is not bound to VFIO. Cannot start macOS VM."
    exit 1
fi

# Wait for the VM to shut down
echo "Waiting for the VM to shut down..."
while pgrep -f "qemu-system-x86_64" > /dev/null; do
    sleep 5
done

# Rebind GPU to i915 after VM shutdown
rebind_gpu_to_i915

echo "GPU rebind complete. VM has been stopped and GPU is now bound to the i915 driver."
