using DataFrames,CSV,Plots,StatsBase, Statistics,Pkg,JSON, FFTW,HTTP

"""
TO DO::
re-compose key magnitudes
found from fft
to create normalized forecast
"""
#using plotly backend so hoverability is enabled
# this will make it easy to find key magnitudes 
# eventually I want to implement a quantum algrorithm to find key frequencies
plotly()
#loading hourly prices for intraday analysis 
function getPrices(token,sequences)
    response = HTTP.get("https://min-api.cryptocompare.com/data/v2/histohour?fsym=$token&tsym=USD&limit=$sequences")
    bod=String(response.body)
    json = JSON.Parser.parse(bod)
    data =json["Data"]["Data"][1:end]
    prices = []
    dataLen = length(data)
    for i in range(1,dataLen)
        jsonClose=data[i]["close"]
        push!(prices,jsonClose)
    end
    return prices
end
#call fucntion to get latest data
prices = getPrices("BTC",2000)



# --savgol for smoothing initial timeseries data
# --savgol filter credit to https://medium.com/@acidflask
# --Jihao Cehn
function savgol_filter_jl(D, M=1, N=1)
    T = typeof(D[1])
    J = zeros(2M+1, N+1)
    for i=1:2M+1, j=1:N+1
        J[i, j] = (i-M-1)^(j-1)
    end
    e₁ = zeros(N+1) 
    e₁[1] = 1.0
    C = J' \ e₁
    To = typeof(C[1] * one(T)) 
    n = size(D, 1)
    filtered = zeros(To, n)
    for i in eachindex(filtered)
		for j=1:M
            if i - j ≥ 1
                filtered[i] += (C[M+1-j])*D[i-j]
            end
            if i + j ≤ n
                filtered[i] += (C[M+1+j])*D[i+j]
            end
        end
		filtered[i] += (C[M+1])*D[i]
    end
    return filtered
end;
#loading dataset via csv
#df = DataFrame(CSV.File("eth-usd-max.csv"))
#dropmissing(df)

#rename prices
price = prices
#smootth price & remove first and last 10 sequences
sPrice = savgol_filter_jl(price,10,1)[10:end-10]
plot(price)
plot!(sPrice)

#construct derivative to center price 
#raw prices
"""
I cosntruct two derivatives
to show
massive difference betweeen 
savgol price and raw prices
following the fft...
almost impossible to find key mangitudes
with raw price
"""
v = price[1:end-1]
b = price[2:end]
priceDt = b - v
#smooth derivative
v = sPrice[1:end-1]
b = sPrice[2:end]
sPriceDt = b - v
sPriceDt = sPriceDt[3:end]

#plot stationary price vs normal price
plot((priceDt))
#savgol filtering looks much better
plot!(sPriceDt*10)

#autocorrelation with 48 day sliding lag window
#raw autocor
ac = StatsBase.autocor(priceDt,[1:48;];demean=true)
#smooth autocor
sac=StatsBase.autocor(sPriceDt,[1:48;];demean=true)
plot(ac,line=:stem,marker=:star)
#smoothed data ==> much more stationary
plot(sac,line=:stem,marker=:star)


# FFT on raw
fftB = fft(priceDt)
fftC = fft(sPriceDt)
t = 1/24
n = size(fftC,1)
n2=size(fftB,1)
freq = LinRange(1,1/t,n)
freq2 = LinRange(1,1/n2,n2)
fPriceB = broadcast(abs,fftB)[1:n2 ÷ 2]*1/n2
fPriceC = broadcast(abs,fftC)[1:n ÷ 2] *1/n
#plotting results raw vs smooth

bar(freq2[1:n2 ÷2],fPriceB,color="black",label="freq",title="Fourier Magnitude")
#smooth data ==> !!! SIGNIFIGANT DIFFERENCE !!!
bar(freq[1:n ÷2],fPriceC,color="black",label="freq",title="Fourier Magnitude")

#create sin waves of key frequencies
#done by hand using plotly inteeractive bar chart
# from above

#function to find periood
#using key magnitudes
function getPeriod(magnitude)
    ω = magnitude / 24
    T = 1 / ω
    return T
end

# will extend wave lengths past end of 
# indices time series for forecasting
predictionLength=50

waveLength = predictionLength + length(price)

v = 5.5sin.(2π/21.81 .* (1:waveLength))
v2 = 1.05sin.(2π/9.2148 .* (1:waveLength))
v3 = 0.66sin.(2π/6.55 .* (1:waveLength))
v4 = 0.44sin.(2π/5.0526 .* (1:waveLength))
#plotting last 200 days no forecasting
plot1=plot(v[end-400:end-200])
plot2=plot(v2[end-400:end-200])
plot3=plot(v3[end-400:end-200])
plot4=plot(v4[end-400:end-200])
plot5=plot(price[end-200:end])



plot(plot1,plot2,plot3,plot4,plot5,layout=grid(5,1))



#fourier = freq[1:n ÷ 2]
#fPrice = price[1:end-1297]
#plot(fourier,j,title="Fourier Magnitude")
v=v.+25
#price with fourier forecasting
plot(price[end-200:end]/600,title="Fourier forecasting")
plot!(v[end-400:end])


