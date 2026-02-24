using System.Threading.Tasks;
using InterviewMasterApp.Domain.Entities;

namespace InterviewMasterApp.Infrastructure.Capture
{
    public interface IScreenCaptureService
    {
        /// <summary>
        /// Capture the primary screen and return a result containing the Screenshot entity or an error.
        /// </summary>
        Task<ScreenCaptureResult> CaptureScreenAsync();
    }
}

