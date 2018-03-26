module Monitor

const machines = [@sprintf("astm%02d", astm) for astm=4:13]
const interfaces = ["eth0", "ib0"]

function netstat()
    result = readstring(`pdsh -w astm\[04-13\] netstat --interfaces`)
    lines  = split(result, "\n")
    line_words = [split(line) for line in lines]
    Rx = Dict(machine => Dict{String, Int}() for machine in machines)
    Tx = Dict(machine => Dict{String, Int}() for machine in machines)
    for words in line_words
        length(words) == 13 || continue
        words[2] == "Iface" && continue
        machine   = strip(words[1], ':')
        interface = words[2]
        Rx[machine][interface] = parse(Int, words[5])
        Tx[machine][interface] = parse(Int, words[9])
    end
    NetStats(time_ns(), Rx, Tx)
end

struct NetStats
    time :: UInt64
    Rx :: Dict{String, Dict{String, Int}}
    Tx :: Dict{String, Dict{String, Int}}
end

mutable struct Tracker
    before :: NetStats
    after  :: NetStats
end

function Tracker()
    before = netstat()
    sleep(0.01)
    after  = netstat()
    Tracker(before, after)
end

function display(tracker)
    @printf("┌──────")
    for machine in machines
        @printf("┬─────────")
    end
    @printf("┐\n")

    @printf("│      │")
    for machine in machines
        @printf(" %7s │", machine)
    end
    @printf("\n")

    @printf("│      │")
    for machine in machines
        @printf(" %7s │", "pckt/s")
    end
    @printf("\n")

    Δt = (tracker.after.time - tracker.before.time)/1e9

    for interface in interfaces
        @printf("├──────")
        for machine in machines
            @printf("┼─────────")
        end
        @printf("┤\n")

        # FIRST LINE
        @printf("│ %4s │", interface)
        for machine in machines
            ΔRx = tracker.after.Rx[machine][interface] - tracker.before.Rx[machine][interface]
            @printf(" Rx %4.0f │", ΔRx / Δt)
        end
        @printf("\n")

        # SECOND LINE
        @printf("│ %4s │", "")
        for machine in machines
            ΔTx = tracker.after.Tx[machine][interface] - tracker.before.Tx[machine][interface]
            @printf(" Tx %4.0f │", ΔTx / Δt)
        end
        @printf("\n")
    end

    @printf("└──────")
    for machine in machines
        @printf("┴─────────")
    end
    @printf("┘\n")
end

function return_to_top(tracker::Tracker)
    N = length(interfaces)
    for idx = 1:3N+4
        print("\033[F") # go back to the top
    end
end

function track()
    tracker = Tracker()
    display(tracker)
    while true
        sleep(5)
        tracker.before = tracker.after
        tracker.after  = netstat()
        return_to_top(tracker)
        display(tracker)
    end
end

function main()
    try
        track()
    catch exception
        if exception isa InterruptException
            quit()
        else
            rethrow(exception)
        end
    end
end

end

