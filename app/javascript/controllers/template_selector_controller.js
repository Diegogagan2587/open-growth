import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["selection", "select", "info", "categorySelect", "descriptionField", "amountField", "amountHint", "notesField"]
  static values = {
    templates: Array,
    editMode: Boolean
  }

  connect() {
    this.toggleSelection()
    
    if (this.hasSelectTarget && this.selectTarget.value) {
      const templateId = parseInt(this.selectTarget.value)
      const template = this.templatesValue.find(t => t.id === templateId)
      if (template) {
        this.updateFormFromTemplate(template)
      }
    }
  }

  toggle() {
    this.toggleSelection()
  }

  selectTemplate() {
    const templateId = parseInt(this.selectTarget.value)
    if (!templateId) {
      this.updateFormFromTemplate(null)
      return
    }

    const template = this.templatesValue.find(t => t.id === templateId)
    if (template) {
      this.updateFormFromTemplate(template)
    }
  }

  toggleSelection() {
    if (!this.hasSelectionTarget) return
    
    const useTemplateYes = this.element.querySelector('input[value="yes"]')
    const useTemplateNo = this.element.querySelector('input[value="no"]')
    
    if (!useTemplateYes || !useTemplateNo) return

    const useTemplate = useTemplateYes.checked
    
    if (useTemplate) {
      this.selectionTarget.style.display = ""
      this.selectionTarget.classList.remove("hidden")
      
      if (useTemplateYes.closest('label')) {
        useTemplateYes.closest('label').classList.add('border-indigo-500')
      }
      
      if (this.hasSelectTarget) {
        const select = this.selectTarget
        void select.offsetHeight
        if (select.value) {
          this.selectTemplate()
        }
      }
    } else {
      this.selectionTarget.style.display = "none"
      this.selectionTarget.classList.add("hidden")
      if (useTemplateNo.closest('label')) {
        useTemplateNo.closest('label').classList.add('border-indigo-500')
      }
      if (this.hasSelectTarget) {
        this.selectTarget.value = ""
      }
      this.updateFormFromTemplate(null)
    }
  }

  updateFormFromTemplate(template) {
    if (template) {
      if (this.hasCategorySelectTarget) {
        this.categorySelectTarget.value = template.category_id
      }
      if (this.hasDescriptionFieldTarget) {
        this.descriptionFieldTarget.value = template.description || ""
      }
      if (this.hasAmountFieldTarget && !this.editModeValue) {
        this.amountFieldTarget.value = template.amount.toFixed(2)
        if (this.hasAmountHintTarget) {
          this.amountHintTarget.textContent = `${template.frequency} recurring amount`
        }
      }
      if (this.hasNotesFieldTarget) {
        this.notesFieldTarget.value = template.notes || ""
      }
      
      if (this.hasInfoTarget) {
        this.infoTarget.innerHTML = `
          <div class="space-y-2">
            <h4 class="font-medium text-gray-900">${template.description || 'Template'}</h4>
            <div class="grid grid-cols-2 gap-4 text-sm">
              <div>
                <p class="text-gray-600">Amount</p>
                <p class="font-semibold text-gray-900">$${template.amount.toFixed(2)}</p>
              </div>
              <div>
                <p class="text-gray-600">Frequency</p>
                <p class="font-semibold text-gray-900">${template.frequency}</p>
              </div>
            </div>
          </div>
        `
      }
    } else {
      if (this.hasAmountFieldTarget) {
        this.amountFieldTarget.placeholder = "0.00"
        if (this.hasAmountHintTarget) {
          this.amountHintTarget.textContent = ""
        }
      }
      if (this.hasInfoTarget) {
        this.infoTarget.innerHTML = ""
      }
    }
  }
}
