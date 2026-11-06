package com.example.vendortask.adapter.out.external;

import com.example.vendortask.domain.port.out.VendorLookupPort;

import java.util.Optional;

public class VendorRestAdapter implements VendorLookupPort {

    @Override
    public Optional<String> findName(long vendorId) {
        return Optional.empty();
    }
}
