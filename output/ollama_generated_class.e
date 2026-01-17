note
    description: "A simple counter utility with full specifications"
class
    COUNTER
create
    make
feature {NONE} -- Initialization
    make
        do
            value := 0
        ensure
            initialized: value = 0
        end
feature -- Access
    current_value: INTEGER
        do
            Result := value
        ensure
            not_void: Result >= 0
        end
feature -- Element change
    increment
        require
            pre: True
        do
            value := value + 1
        ensure
            incremented: value = old value + 1
            non_negative: value >= 0
        end
    decrement
        require
            positive: value > 0
        do
            value := value - 1
        ensure
            decremented: value = old value - 1
            non_negative: value >= 0
        end
    reset_count
        do
            value := 0
        ensure
            is_zero: value = 0
            non_negative: value >= 0
        end
invariant
    non_negative: value >= 0
end