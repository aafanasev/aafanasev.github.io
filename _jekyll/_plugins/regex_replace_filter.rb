module Jekyll 
    module RegexReplaceFilter
        def regex_replace(input, regex, replace)
            reg = Regexp.new regex
            input.gsub(reg, replace)
        end
    end
end

Liquid::Template.register_filter(Jekyll::RegexReplaceFilter)