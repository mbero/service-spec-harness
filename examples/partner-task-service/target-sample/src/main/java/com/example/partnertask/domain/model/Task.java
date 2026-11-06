package com.example.partnertask.domain.model;

/** A unit of work assigned to exactly one partner. */
public record Task(long id, String title, TaskStatus status, long partnerId) {
}
