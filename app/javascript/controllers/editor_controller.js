import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["title", "content"]
  static values = { saveUrl: String }
  
  connect() {
    this.saveTimeout = null
    this.lastSaved = Date.now()
    this.setupAutoSave()
    this.updateWordCount()
  }
  
  disconnect() {
    if (this.saveTimeout) {
      clearTimeout(this.saveTimeout)
    }
    if (this.autoSaveInterval) {
      clearInterval(this.autoSaveInterval)
    }
  }
  
  setupAutoSave() {
    // Auto-save every 30 seconds of inactivity
    this.autoSaveInterval = setInterval(() => {
      if (Date.now() - this.lastSaved > 30000) {
        this.performAutoSave()
      }
    }, 30000)
  }
  
  autoSave() {
    if (this.saveTimeout) {
      clearTimeout(this.saveTimeout)
    }
    
    this.saveTimeout = setTimeout(() => {
      this.performAutoSave()
    }, 2000) // Save 2 seconds after user stops typing
    
    this.lastSaved = Date.now()
    this.updateWordCount()
  }
  
  // Handle Trix content changes
  trixChange() {
    this.autoSave()
  }
  
  async performAutoSave() {
    // Only auto-save if we have a title or content
    const title = this.titleTarget.value.trim()
    const content = this.contentTarget.value.trim()
    
    if (!title && !content) {
      return
    }
    
    const formData = new FormData()
    formData.append('post[title]', title)
    formData.append('post[content]', content)
    
    this.updateSaveStatus('Saving...')
    
    try {
      const response = await fetch(this.saveUrlValue, {
        method: this.saveUrlValue.includes('/posts/') ? 'PATCH' : 'POST',
        body: formData,
        headers: {
          'X-CSRF-Token': this.getCSRFToken(),
          'Accept': 'application/json'
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        this.updateSaveStatus('Draft saved', 'success')
        
        // Update URL if this was a new post
        if (data.redirect_url && !this.saveUrlValue.includes('/posts/')) {
          this.saveUrlValue = data.redirect_url
          // Update browser URL without reload
          window.history.replaceState({}, '', data.redirect_url.replace('/posts/', '/posts/').replace('/edit', '/edit'))
        }
      } else {
        throw new Error('Save failed')
      }
    } catch (error) {
      console.error('Save failed:', error)
      this.updateSaveStatus('Error saving', 'error')
    }
  }
  
  updateWordCount() {
    const content = this.contentTarget.value || ''
    // Simple HTML tag removal for word count
    const plainText = content.replace(/<[^>]*>/g, '').replace(/&nbsp;/g, ' ')
    const words = plainText.trim().split(/\s+/).filter(word => word.length > 0)
    const wordCount = words.length
    const readingTime = Math.max(1, Math.ceil(wordCount / 200))
    
    const wordCountEl = document.querySelector('#word-count')
    const readingTimeEl = document.querySelector('#reading-time')
    
    if (wordCountEl) wordCountEl.textContent = wordCount
    if (readingTimeEl) readingTimeEl.textContent = `${readingTime} min`
  }
  
  updateSaveStatus(message, type = '') {
    const saveStatus = document.querySelector('.save-status')
    if (saveStatus) {
      saveStatus.textContent = message
      saveStatus.className = `save-status ${type ? `save-${type}` : ''}`
    }
  }
  
  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') : ''
  }
}
