package com.example.vendortask.adapter.in.web;

import com.example.vendortask.domain.model.Task;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class TaskController {

    @GetMapping("/api/v1/tasks/{taskId}")
    public Task get(@PathVariable long taskId) {
        return new Task(taskId, "Replace brake pads", null, 42L);
    }
}
