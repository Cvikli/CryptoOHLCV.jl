
struct MeanNorm
  mean
end
function denorm(norm::MeanNorm, y)
  y .*= norm.mean
end
function norm(normer::MeanNorm, x) 
  x ./ normer.mean
end
norm!(normer::MeanNorm, x) = x ./= normer.mean
