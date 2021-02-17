import { Decimal } from 'decimal.js'
import { BigNumberish } from 'ethers'

export function formatTokenAmount(num: BigNumberish): string {
  return new Decimal(num.toString()).dividedBy(new Decimal(10).pow(18)).toPrecision(5)
}

export function formatPrice(price: BigNumberish): string {
  return new Decimal(price.toString()).dividedBy(new Decimal(2).pow(96)).pow(2).toPrecision(5)
}
