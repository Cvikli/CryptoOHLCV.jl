
struct MeanNorm
  mean
end
denorm!(normer::MeanNorm, y) = y .*= normer.mean
norm!(  normer::MeanNorm, x) = x ./= normer.mean
norm(   normer::MeanNorm, x) = x ./  normer.mean
