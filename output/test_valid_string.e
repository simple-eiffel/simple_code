note
	description: "A simple test entity"

class
	TEST_CLASS

create
	make

feature {NONE} -- Initialization

	make
		do
			value := 0
		end

feature -- Access

	value: INTEGER

end
