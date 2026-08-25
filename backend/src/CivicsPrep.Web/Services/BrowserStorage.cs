using Microsoft.JSInterop;

namespace CivicsPrep.Web.Services;

/// <summary>
/// Reads and writes browser local storage. Tokens are kept here so a page refresh does not sign
/// the user out. Small enough to own directly rather than take a dependency for.
/// </summary>
public interface IBrowserStorage
{
    ValueTask<string?> GetAsync(string key, CancellationToken ct = default);
    ValueTask SetAsync(string key, string value, CancellationToken ct = default);
    ValueTask RemoveAsync(string key, CancellationToken ct = default);
}

public class BrowserStorage(IJSRuntime js) : IBrowserStorage
{
    public async ValueTask<string?> GetAsync(string key, CancellationToken ct = default)
    {
        try
        {
            return await js.InvokeAsync<string?>("localStorage.getItem", ct, key);
        }
        catch (JSException)
        {
            // Private browsing and blocked-storage settings both throw here.
            return null;
        }
    }

    public async ValueTask SetAsync(string key, string value, CancellationToken ct = default)
    {
        try
        {
            await js.InvokeVoidAsync("localStorage.setItem", ct, key, value);
        }
        catch (JSException) { /* storage unavailable; the session stays in memory only */ }
    }

    public async ValueTask RemoveAsync(string key, CancellationToken ct = default)
    {
        try
        {
            await js.InvokeVoidAsync("localStorage.removeItem", ct, key);
        }
        catch (JSException) { /* nothing to remove if storage is unavailable */ }
    }
}
