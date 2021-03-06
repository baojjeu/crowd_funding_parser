require 'httparty'
require "active_support/all"
require_relative "method_builder"

module CrowdFundingParser
  module Parser
    class General
      include HTTParty

      def parse_tracking_data(result, project_url)
        project = Hash.new
        project["money_goal"]      = get_money_goal(result).to_i
        project["money_pledged"]   = get_money_pledged(result).to_i
        project["backer_count"]    = get_backer_count(result).to_i
        project["left_time"]       = get_left_time(result)
        project["status"]          = get_status(project["left_time"])
        project["fb_count"]        = get_fb_count(result).to_i
        project["following_count"] = get_following_count(result).to_i
        project
      end

      def parse_content_data(result, project_url)
        project                    = Hash.new
        project["platform_project_id"] = get_id(project_url)
        project["title"]           = get_title(result)
        project["url"]             = project_url
        project["summary"]         = get_summary(result)
        project["category"]        = get_category(result)
        project["creator_name"]    = get_creator_name(result)
        project["creator_id"]      = get_creator_id(result)
        project["creator_link"]    = get_creator_link(result)
        project["currency_string"] = get_currency_string(result)
        project["start_date"]      = get_start_date(result)
        project["end_date"]        = get_end_date(result)
        project["region"]          = get_region(result)
        project
      end

      def get_project_links(required_status = "online")
        links = []

        get_lists.each do |target|
          doc = Nokogiri::HTML(target)
          online_projects = doc.css(@item_css_class)

          Parallel.map(online_projects, in_processes: 2 , in_threads: 4) do |project|
            link_nodes = project.css("a:nth-child(1)")
            status = get_status(get_string(project.css(@status_css_class)))
            link = @platform_url + link_nodes.first["href"]
            if status == required_status
              links << link
            end
          end
        end

        links
      end

      def get_result(project_url)
        if @parse_method == :json
          project_id = get_id(project_url)
          project_api = get_project_api(project_id)
          get_json_through_url(project_api)
        else
          get_doc_through_url(project_url)
        end
      end

      def get_doc_through_url(project_url)
        project_html = HTTParty.get(project_url)
        Nokogiri::HTML(project_html)
      end

      def get_json_through_url(project_url)
        httparty_url = HTTParty.get(project_url)
        json = JSON.load(httparty_url.body)
      end

      def get_project(project_url)
        result = get_result(project_url)
        parse_content_data(result, project_url).merge parse_tracking_data(result, project_url)
      end

      def get_id(project_url)
        rel_url = get_rel_url(project_url)
        rel_url.split("/").last.split("?").first
      end

      private

      def get_rel_url(url)
        url.gsub("#{@platform_url}", "")
      end

      def method_missing(m, *args, &block)
        if m.to_s.match(/get/)
          ""
        else
          super
        end
      end
    end
  end
end
