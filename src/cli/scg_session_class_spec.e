note
	description: "[
		Class specification within a code generation session.

		Tracks the name, description, features, and generation status
		of a single class in the generation pipeline.
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_SESSION_CLASS_SPEC

create
	make

feature {NONE} -- Initialization

	make (a_name: STRING_32; a_description: STRING_32; a_features: ARRAYED_LIST [STRING_32])
			-- Create class specification.
		require
			name_not_empty: a_name /= Void and then not a_name.is_empty
		do
			name := a_name
			if attached a_description then
				description := a_description
			else
				create description.make_empty
			end
			if attached a_features then
				features := a_features
			else
				create features.make (0)
			end
			create generated_code.make_empty
		ensure
			name_set: name = a_name
		end

feature -- Status

	is_generated: BOOLEAN
			-- Has this class been generated?

feature -- Access

	name: STRING_32
			-- Class name (e.g., "LIBRARY_BOOK")

	description: STRING_32
			-- Description of class purpose

	features: ARRAYED_LIST [STRING_32]
			-- List of feature names to include

	generated_code: STRING_32
			-- Generated Eiffel code (if is_generated)

feature -- Element change

	set_generated (a_code: STRING_32)
			-- Mark this class as generated with `a_code'.
		require
			code_not_empty: not a_code.is_empty
		do
			generated_code := a_code
			is_generated := True
		ensure
			is_generated: is_generated
			code_set: generated_code = a_code
		end

	set_description (a_description: STRING_32)
			-- Set the class description.
		require
			description_not_void: a_description /= Void
		do
			description := a_description
		ensure
			description_set: description = a_description
		end

	add_feature (a_feature_name: STRING_32)
			-- Add a feature to generate.
		require
			name_not_empty: not a_feature_name.is_empty
		do
			features.extend (a_feature_name)
		ensure
			feature_added: features.has (a_feature_name)
		end

invariant
	name_not_empty: not name.is_empty
	description_exists: description /= Void
	features_exists: features /= Void
	generated_code_exists: generated_code /= Void
	generated_implies_code: is_generated implies not generated_code.is_empty

end
