using System;

namespace InterviewMasterApp.Domain.ValueObjects
{
    /// <summary>
    /// Value object representing a unique session identifier.
    /// Migrated from Swift: SessionId.swift
    /// </summary>
    public class SessionId
    {
        public Guid Value { get; }

        /// <summary>
        /// Create a new unique session ID.
        /// </summary>
        public SessionId()
        {
            Value = Guid.NewGuid();
        }

        /// <summary>
        /// Recreate from existing GUID.
        /// </summary>
        public SessionId(Guid guid)
        {
            Value = guid;
        }

        /// <summary>
        /// String representation (UUID string format).
        /// </summary>
        public string StringValue => Value.ToString();

        public override bool Equals(object? obj)
        {
            return obj is SessionId other && Value == other.Value;
        }

        public override int GetHashCode()
        {
            return Value.GetHashCode();
        }

        public override string ToString()
        {
            return Value.ToString();
        }

        public static bool operator ==(SessionId? left, SessionId? right)
        {
            if (ReferenceEquals(left, right))
                return true;
            if (ReferenceEquals(left, null) || ReferenceEquals(right, null))
                return false;
            return left.Value == right.Value;
        }

        public static bool operator !=(SessionId? left, SessionId? right)
        {
            return !(left == right);
        }
    }
}
