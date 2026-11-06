package com.example.partnertask.domain.port.out;

import java.util.Optional;

/** Resolves a partner name, or nothing when the upstream is unavailable. */
public interface PartnerLookupPort {

    Optional<String> findName(long partnerId);
}
