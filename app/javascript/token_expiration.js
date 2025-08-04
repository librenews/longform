// Token expiration handling for AJAX requests
class TokenExpirationHandler {
  constructor() {
    this.initializeAjaxHandlers();
    this.initializeFormSaving();
  }

  initializeAjaxHandlers() {
    // Intercept all AJAX responses for unauthorized errors
    document.addEventListener('ajax:error', (event) => {
      const xhr = event.detail[0];
      
      if (xhr.status === 401) {
        const response = JSON.parse(xhr.responseText);
        if (response.error === 'Session expired') {
          this.handleSessionExpiration(response);
        }
      }
    });
  }

  initializeFormSaving() {
    // Auto-save form data periodically for critical forms
    const forms = document.querySelectorAll('form[data-auto-save]');
    
    forms.forEach(form => {
      const interval = form.dataset.autoSaveInterval || 30000; // 30 seconds default
      
      setInterval(() => {
        this.saveFormData(form);
      }, interval);
    });
  }

  handleSessionExpiration(response) {
    // Show a user-friendly message
    this.showSessionExpiredModal(response);
  }

  showSessionExpiredModal(response) {
    // Create modal if it doesn't exist
    let modal = document.getElementById('session-expired-modal');
    
    if (!modal) {
      modal = this.createSessionExpiredModal();
      document.body.appendChild(modal);
    }

    // Update message based on whether data was preserved
    const messageEl = modal.querySelector('.session-message');
    if (response.preserved_data) {
      messageEl.textContent = "Your session has expired, but we've saved your work. Please sign in to continue.";
    } else {
      messageEl.textContent = "Your session has expired. Please sign in to continue.";
    }

    // Show modal
    modal.style.display = 'flex';
  }

  createSessionExpiredModal() {
    const modal = document.createElement('div');
    modal.id = 'session-expired-modal';
    modal.className = 'session-expired-modal';
    
    modal.innerHTML = `
      <div class="modal-overlay">
        <div class="modal-content">
          <h3>Session Expired</h3>
          <p class="session-message"></p>
          <div class="modal-actions">
            <button onclick="window.location.href='/'" class="btn btn-primary">
              Sign In Again
            </button>
          </div>
        </div>
      </div>
    `;

    return modal;
  }

  saveFormData(form) {
    // Don't save if user is actively typing
    if (this.isUserTyping()) return;

    const formData = new FormData(form);
    const data = {};
    
    for (let [key, value] of formData.entries()) {
      data[key] = value;
    }

    // Store in localStorage as backup
    localStorage.setItem('form-backup-' + form.id, JSON.stringify({
      data: data,
      timestamp: Date.now(),
      url: window.location.pathname
    }));
  }

  isUserTyping() {
    // Simple check to see if user typed recently
    const now = Date.now();
    const lastKeypress = window.lastKeypressTime || 0;
    return (now - lastKeypress) < 2000; // 2 seconds
  }

  restoreFormData(formId) {
    const backup = localStorage.getItem('form-backup-' + formId);
    if (!backup) return false;

    try {
      const { data, timestamp, url } = JSON.parse(backup);
      
      // Don't restore if backup is too old (1 hour)
      if (Date.now() - timestamp > 3600000) {
        localStorage.removeItem('form-backup-' + formId);
        return false;
      }

      // Don't restore if we're on a different page
      if (url !== window.location.pathname) return false;

      const form = document.getElementById(formId);
      if (!form) return false;

      // Restore form values
      Object.entries(data).forEach(([key, value]) => {
        const input = form.querySelector(`[name="${key}"]`);
        if (input) {
          input.value = value;
          
          // Trigger events for modern form libraries
          input.dispatchEvent(new Event('input', { bubbles: true }));
          input.dispatchEvent(new Event('change', { bubbles: true }));
        }
      });

      // Clean up
      localStorage.removeItem('form-backup-' + formId);
      return true;
    } catch (e) {
      console.error('Failed to restore form data:', e);
      return false;
    }
  }
}

// Track keypresses for typing detection
document.addEventListener('keypress', () => {
  window.lastKeypressTime = Date.now();
});

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  window.tokenHandler = new TokenExpirationHandler();
  
  // Try to restore form data for forms with IDs
  document.querySelectorAll('form[id]').forEach(form => {
    window.tokenHandler.restoreFormData(form.id);
  });
});
