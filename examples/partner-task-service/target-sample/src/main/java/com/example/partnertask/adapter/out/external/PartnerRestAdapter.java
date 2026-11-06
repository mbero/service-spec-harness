package com.example.partnertask.adapter.out.external;

import com.example.partnertask.domain.port.out.PartnerLookupPort;

import java.util.Optional;

public class PartnerRestAdapter implements PartnerLookupPort {

    @Override
    public Optional<String> findName(long partnerId) {
        return Optional.empty();
    }
}
