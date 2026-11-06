package com.example.vendortask.application;

import com.example.vendortask.domain.model.Task;
import com.example.vendortask.domain.port.out.VendorLookupPort;

import java.util.Optional;

/** Serves one task with its vendor name resolved, degrading when the lookup fails. */
public class GetTaskUseCase {

    private final VendorLookupPort vendorLookup;

    public GetTaskUseCase(VendorLookupPort vendorLookup) {
        this.vendorLookup = vendorLookup;
    }

    public Optional<String> resolveVendorName(Task task) {
        return vendorLookup.findName(task.vendorId());
    }
}
