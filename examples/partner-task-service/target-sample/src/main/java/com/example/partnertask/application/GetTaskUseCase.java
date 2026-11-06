package com.example.partnertask.application;

import com.example.partnertask.domain.model.Task;
import com.example.partnertask.domain.port.out.PartnerLookupPort;

import java.util.Optional;

/** Serves one task with its partner name resolved, degrading when the lookup fails. */
public class GetTaskUseCase {

    private final PartnerLookupPort partnerLookup;

    public GetTaskUseCase(PartnerLookupPort partnerLookup) {
        this.partnerLookup = partnerLookup;
    }

    public Optional<String> resolvePartnerName(Task task) {
        return partnerLookup.findName(task.partnerId());
    }
}
