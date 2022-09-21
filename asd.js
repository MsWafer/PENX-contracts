let arr = [];
let staked = 100;
let price = 2;
let sum = 0;
let x = 30;
let sum1 = 0;
let average;
for (let i = 1; i < 366; i++) {
    // arr.push(i)
    // arr.push(staked*Math.sqrt(i))
    sum1 += ((staked * Math.sqrt(i)) / price) * x
    sum += i;
}
average = Math.sqrt(sum / 365);
console.log(sum/365,average)
console.log(sum1)
console.log(((staked * (sum/365)) / price) * x)
