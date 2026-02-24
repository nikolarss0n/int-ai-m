using System;
using System.Runtime.InteropServices;
using System.Security;
using System.Text;

namespace InterviewMasterApp.Infrastructure.Storage
{
    /// <summary>
    /// Windows Credential Manager wrapper for storing API keys securely.
    /// Uses the Credential Management API via P/Invoke.
    /// </summary>
    public class WindowsCredentialApiKeyStore
    {
        private readonly string _target;
        private readonly string _username;

        public WindowsCredentialApiKeyStore(string target = "InterviewMaster.ApiKey", string username = "default")
        {
            _target = target;
            _username = username;
        }

        public bool Save(string apiKey)
        {
            try
            {
                var cred = new NativeMethods.CREDENTIAL
                {
                    TargetName = _target,
                    UserName = _username,
                    CredentialBlob = Marshal.StringToCoTaskMemUni(apiKey),
                    CredentialBlobSize = (uint)Encoding.Unicode.GetByteCount(apiKey),
                    Type = NativeMethods.CRED_TYPE_GENERIC,
                    Persist = NativeMethods.CRED_PERSIST_LOCAL_MACHINE
                };

                var result = NativeMethods.CredWrite(ref cred, 0);
                Marshal.FreeCoTaskMem(cred.CredentialBlob);
                return result;
            }
            catch
            {
                return false;
            }
        }

        public string Retrieve()
        {
            if (NativeMethods.CredRead(_target, NativeMethods.CRED_TYPE_GENERIC, 0, out IntPtr credPtr))
            {
                try
                {
                    var cred = Marshal.PtrToStructure<NativeMethods.CREDENTIAL>(credPtr);
                    if (cred.CredentialBlobSize > 0 && cred.CredentialBlob != IntPtr.Zero)
                    {
                        var apiKey = Marshal.PtrToStringUni(cred.CredentialBlob, (int)cred.CredentialBlobSize / 2);
                        return apiKey;
                    }
                }
                finally
                {
                    NativeMethods.CredFree(credPtr);
                }
            }
            return null;
        }

        public bool Delete()
        {
            return NativeMethods.CredDelete(_target, NativeMethods.CRED_TYPE_GENERIC, 0);
        }

        private static class NativeMethods
        {
            public const int CRED_TYPE_GENERIC = 1;
            public const int CRED_PERSIST_LOCAL_MACHINE = 2;

            [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
            public struct CREDENTIAL
            {
                public uint Flags;
                public uint Type;
                public string TargetName;
                public string Comment;
                public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
                public uint CredentialBlobSize;
                public IntPtr CredentialBlob;
                public uint Persist;
                public uint AttributeCount;
                public IntPtr Attributes;
                public string TargetAlias;
                public string UserName;
            }

            [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
            public static extern bool CredWrite([In] ref CREDENTIAL Credential, [In] uint Flags);

            [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
            public static extern bool CredRead(string target, int type, int reservedFlag, out IntPtr credentialPtr);

            [DllImport("advapi32.dll", SetLastError = true)]
            public static extern bool CredFree([In] IntPtr Buffer);

            [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
            public static extern bool CredDelete(string target, int type, int flags);
        }
    }
}

