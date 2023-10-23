 # app/controllers/challenges_controller.rb
class ChallengesController < ApplicationController
  include ChallengesHelper
  before_action :require_user

    def new
      @challenge = Challenge.new
      @instructor = Instructor.find_by(user_id: session[:user_id])
      Rails.logger.debug(@instructor)
      unless @instructor
        flash[:alert] = "You are not an instructor."
        redirect_to root_path
        return
      end
      @is_instructor = true
    end
  
    def create
      @challenge = Challenge.new(challenge_params)
      @instructor = Instructor.find_by(user_id: session[:user_id])
      @challenge.instructor = @instructor
     
      if Challenge.find_by(name: @challenge.name)
        flash[:alert] = "A challenge with the same name already exists."
        redirect_to new_challenge_path
        return
      end

      if params[:challenge][:startDate]>params[:challenge][:endDate]
        flash[:alert] = "start date is greater than end date"
        redirect_to new_challenge_path
        return
      end

      existing_tasks = []

      if params[:challenge][:tasks_attributes].present?
      params[:challenge][:tasks_attributes].each do |task_attributes|
        task_name = task_attributes[1][:taskName]
        # Check if a task with the same name already exists
        existing_task = Task.find_by(taskName: task_name)
    
        if existing_task
          existing_tasks << existing_task
        else
          new_task = Task.new(taskName: task_name)
          existing_tasks << new_task
        end
      end
    end
    
      # Replace the task attributes with the existing tasks
      @challenge.tasks = existing_tasks


      if @challenge.save
        flash[:notice] = "Challenge successfully created."
        redirect_to new_challenge_path
        return
      end
    end

    def show
      @instructor = Instructor.find_by(user_id: session[:user_id])

      if @instructor
        begin
          @challenge = Challenge.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          flash[:alert] = "Challenge not found."
          redirect_to challenges_path
        end
      else
        flash[:notice] = "You are not an instructor."
        redirect_to root_path
      end
    end

    def trainees_list
      @challenge = Challenge.find(params[:challenge_id])
      trainees = Trainee.joins(:challenge_trainees).where(challenge_trainees: { challenge_id: params[:challenge_id]})
      page = params[:page].presence || 1
      @trainees_ct = trainees.size
      @trainees = trainees.paginate(page: params[:page], per_page: 10)
      puts @trainees
    end
  
    def add_trainees
      @challenge = Challenge.find(params[:id])
      if @challenge.startDate <= Date.today
        flash.now[:alert] = "Challenge has already started. You cannot add trainees."
        @trainees = []
      else
        @challenge_trainees = ChallengeTrainee.where(challenge_id: params[:id])
        trainee_ids = @challenge_trainees.pluck(:trainee_id)
        @trainees = Trainee.where.not(id: trainee_ids)
      end
    end

    def update_trainees
      @challenge = Challenge.find(params[:id])
      if @challenge.trainees << Trainee.where(id: params[:trainee_ids])        
        flash.now[:notice] = "Trainees were successfully added to the challenge."
        @challenge.trainees.each do |trainee|
          tasks = @challenge.tasks
          tasks.each do |task|
            (@challenge.startDate..@challenge.endDate).each do |date|
              tasktodo = TodolistTask.new(
                task: task,
                trainee: trainee,      
                challenge: @challenge, 
                date: date            
              )
              if tasktodo.save
                flash.now[:notice] = "Trainees were successfully added to the challenge."
              else
                flash.now[:alert] = "Something went wrong. Challenge was not updated."
              end
          end
        end
      end
      else
        flash.now[:alert] = "Something went wrong. Challenge was not updated."
      end
      @challenge_trainees = ChallengeTrainee.where(challenge_id: params[:id])
      trainee_ids = @challenge_trainees.pluck(:trainee_id)
      @trainees = Trainee.where.not(id: trainee_ids)
      render 'add_trainees'
    end

    def task_progress
      task_completed_counts = TodolistTask.where(trainee_id: params[:trainee_id], challenge_id: params[:id], status: "completed").group(:date).count
      task_not_completed_counts = TodolistTask.where(trainee_id: params[:trainee_id], challenge_id: params[:id], status: "not_completed").group(:date).count
    
      # Get the union of all dates from both completed and not completed tasks
      all_dates = task_completed_counts.keys | task_not_completed_counts.keys
    
      # Initialize arrays for dates and counts with zero counts
      @dates_completed = []
      @counts_completed = []
      @dates_not_completed = []
      @counts_not_completed = []
      @counts_total=[]
    
      # Populate arrays with dates and counts, filling in zeros for missing dates
      all_dates.each do |date|
        @dates_completed << date
        @counts_completed << task_completed_counts[date].to_i
        @dates_not_completed << date
        @counts_not_completed << task_not_completed_counts[date].to_i
        @counts_total<<task_completed_counts[date].to_i+task_not_completed_counts[date].to_i
      end

      @trainee = Trainee.find_by(id: params[:trainee_id])
      @challenge = Challenge.find_by(id: params[:id])
      @trainee_name = @trainee.full_name if @trainee.present?
    end
    
    def filter_data
      selected_date = params[:selected_date]
      trainee_id = params[:trainee_id]
      challenge_id = params[:challenge_id]
      task_ids = TodolistTask.where(trainee_id: trainee_id, challenge_id: challenge_id, date: selected_date).pluck(:task_id)
      @todo_list = Task.where(id: task_ids)
      @filtered_data = @todo_list
      puts @todo_list
      render json: @filtered_data
    end
  
    def show_challenge_trainee
      @challenge = Challenge.find(params[:challenge_id])
      @trainee = @challenge.trainees.find(params[:trainee_id])
      start_date = @challenge.startDate ? (@challenge.startDate > Date.today ? @challenge.startDate : Date.today) : Date.today

      task_ids = TodolistTask.where(trainee_id: @trainee.id, challenge_id: @challenge.id, date: start_date).pluck(:task_id)
      @todo_list = Task.where(id: task_ids)
      @filtered_data = @todo_list

      render 'show_challenge_trainee'
    end

    private
  
    def challenge_params
      params.require(:challenge).permit(:name, :id, :startDate, :endDate, tasks_attributes: [:id, :taskName, :_destroy])
    end

    def require_user
      unless user_signed_in? 
        flash[:alert] = "You must be signed in to access this page."
        redirect_to login_path
      end
    end
  end
  