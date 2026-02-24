using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace InterviewMasterApp.Infrastructure.API
{
    // Request DTOs (used for building request JSON)
    public class AnthropicRequest
    {
        [JsonPropertyName("model")] public string Model { get; set; }
        [JsonPropertyName("max_tokens")] public int MaxTokens { get; set; }
        [JsonPropertyName("messages")] public List<AnthropicMessage> Messages { get; set; }
    }

    public class AnthropicMessage
    {
        [JsonPropertyName("role")] public string Role { get; set; }
        [JsonPropertyName("content")] public List<object> Content { get; set; }
    }

    public class TextContent
    {
        [JsonPropertyName("type")] public string Type { get; set; } = "text";
        [JsonPropertyName("text")] public string Text { get; set; }
    }

    public class ImageSource
    {
        [JsonPropertyName("type")] public string Type { get; set; }
        [JsonPropertyName("media_type")] public string MediaType { get; set; }
        [JsonPropertyName("data")] public string Data { get; set; }
    }

    public class ImageContent
    {
        [JsonPropertyName("type")] public string Type { get; set; } = "image";
        [JsonPropertyName("source")] public ImageSource Source { get; set; }
    }

    // Response DTOs
    public class AnthropicResponse
    {
        [JsonPropertyName("id")] public string Id { get; set; }
        [JsonPropertyName("type")] public string Type { get; set; }
        [JsonPropertyName("role")] public string Role { get; set; }
        [JsonPropertyName("content")] public List<ResponseContent> Content { get; set; }
        [JsonPropertyName("model")] public string Model { get; set; }
        [JsonPropertyName("stop_reason")] public string StopReason { get; set; }
        [JsonPropertyName("usage")] public Usage Usage { get; set; }
    }

    public class ResponseContent
    {
        [JsonPropertyName("type")] public string Type { get; set; }
        [JsonPropertyName("text")] public string Text { get; set; }
    }

    public class Usage
    {
        [JsonPropertyName("input_tokens")] public int InputTokens { get; set; }
        [JsonPropertyName("output_tokens")] public int OutputTokens { get; set; }
    }

    // Error response
    public class AnthropicErrorResponse
    {
        [JsonPropertyName("type")] public string Type { get; set; }
        [JsonPropertyName("error")] public AnthropicErrorDetail Error { get; set; }
    }

    public class AnthropicErrorDetail
    {
        [JsonPropertyName("type")] public string Type { get; set; }
        [JsonPropertyName("message")] public string Message { get; set; }
    }
}

