module Projects
  class DocsController < ApplicationController
    before_action :set_project
    before_action :set_doc, only: [ :show, :edit, :update, :destroy ]
    before_action :ensure_doc_access, only: [ :show, :edit, :update, :destroy ]

    def index
      @docs = @project.docs.order(created_at: :desc)
    end

    def show
    end

    def new
      @doc = Doc.new
    end

    def create
      @doc = Doc.new(doc_params)
      @doc.account = Current.account

      if @doc.save
        @project.docs << @doc unless @project.docs.include?(@doc)
        redirect_to project_doc_path(@project, @doc), notice: t("docs.flash.created")
      else
        render :new
      end
    end

    def edit
    end

    def update
      if @doc.update(doc_params)
        respond_to do |format|
          format.html { redirect_to project_doc_path(@project, @doc), notice: t("docs.flash.updated") }
          format.json { render json: { id: @doc.id }, status: :ok }
        end
      else
        respond_to do |format|
          format.html { render :edit }
          format.json { render json: { errors: @doc.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    end

    def destroy
      @doc.destroy
      redirect_to project_docs_path(@project), notice: t("docs.flash.destroyed")
    end

    private

    def set_project
      @project = Project.for_account(Current.account).find(params[:project_id])
    rescue ActiveRecord::RecordNotFound
      redirect_to projects_url
    end

    def set_doc
      @doc = @project.docs.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to project_docs_path(@project)
    end

    def ensure_doc_access
      unless @doc && @doc.account_id == Current.account.id
        redirect_to project_docs_path(@project)
      end
    end

    def doc_params
      params.require(:doc).permit(:title, :content, :doc_type)
    end
  end
end
