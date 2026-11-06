package com.example.vendortask.domain.port.out;

import java.util.Optional;

/** Resolves a vendor name, or nothing when the upstream is unavailable. */
public interface VendorLookupPort {

    Optional<String> findName(long vendorId);
}
