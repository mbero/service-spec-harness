package com.example.vendortask.domain.model;

/** A unit of work assigned to exactly one vendor. */
public record Task(long id, String title, TaskStatus status, long vendorId) {
}
