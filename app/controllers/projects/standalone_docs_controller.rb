module Projects
  class StandaloneDocsController < ApplicationController
    before_action :set_doc, only: [ :show, :edit, :update, :destroy ]
    before_action :ensure_doc_access, only: [ :show, :edit, :update, :destroy ]

    def index
      @docs = Doc.for_account(Current.account).order(created_at: :desc)
    end

    def show
      render partial: "career_doc_panel", layout: false if turbo_frame_request_id == "career_doc_panel"
    end

    def new
      @doc = Doc.new
    end

    def preview
      render html: helpers.render_markdown(params[:content].to_s), layout: false
    end

    def create
      @doc = Doc.new(doc_params)
      @doc.account = Current.account

      if @doc.save
        redirect_to doc_path(@doc), notice: t("docs.flash.created")
      else
        render :new
      end
    end

    def edit
    end

    def update
      if @doc.update(doc_params)
        respond_to do |format|
          format.html { redirect_to doc_path(@doc), notice: t("docs.flash.updated") }
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
      redirect_to docs_path, notice: t("docs.flash.destroyed")
    end

    private

    def set_doc
      @doc = Doc.for_account(Current.account).find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to docs_path
    end

    def ensure_doc_access
      unless @doc && @doc.account_id == Current.account.id
        redirect_to docs_path
      end
    end

    def doc_params
      params.require(:doc).permit(:title, :content, :doc_type)
    end
  end
end
