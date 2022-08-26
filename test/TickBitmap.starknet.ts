import { TickBitmapTest__WC__TickBitmapTest_compiled } from "../typechain-types";
import {expect} from 'chai';
import { getStarknetContractFactory } from 'hardhat-warp/dist/testing'
import BN = require('bn.js')

describe('TickBitmap', () => {
    let tickBitmap: TickBitmapTest__WC__TickBitmapTest_compiled;

    beforeEach('deploy TickBitmapTest', async () => {
        const tickBitmapFactory = getStarknetContractFactory('TickBitmapTest');
        tickBitmap = (await tickBitmapFactory.deploy()) as TickBitmapTest__WC__TickBitmapTest_compiled;
    })

    async function initTicks(ticks: number[]): Promise<void> {
        for (const tick of ticks) {
            if (tick >= 0) {
                await tickBitmap.flipTick_8815912f(tick);
            } else {
                await tickBitmap.flipTick_8815912f(new BN(tick).toTwos(24).toString());
            }
        }
    }

    describe('#isInitilized', () => {
        it('is false at first', async () => {
            const res = await tickBitmap.isInitialized_2bdc2fd3(1);
            const result = Boolean(res[0].toNumber());
            expect(result).to.eq(false);
        })
        it('is flipped by #flipTick', async () => {
            await tickBitmap.flipTick_8815912f(1);
            const res = await tickBitmap.isInitialized_2bdc2fd3(1);
            const result = Boolean(res[0].toNumber());
            expect(result).to.eq(true);
        })
        it('is flipped back by #flipTick', async () => {
            await tickBitmap.flipTick_8815912f(1);
            await tickBitmap.flipTick_8815912f(1);
            const res = await tickBitmap.isInitialized_2bdc2fd3(1);
            const result = Boolean(res[0].toNumber());
            expect(result).to.eq(false);
        })
        it('is not changed by another flip to a different tick', async () => {
            await tickBitmap.flipTick_8815912f(2);
            const res = await tickBitmap.isInitialized_2bdc2fd3(1);
            const result = Boolean(res[0].toNumber());
            expect(result).to.eq(false);
        })
        it('is not changed by another flip to a different tick on another word', async () => {
            await tickBitmap.flipTick_8815912f(1+256);

            let res = await tickBitmap.isInitialized_2bdc2fd3(257);
            let result = Boolean(res[0].toNumber());
            expect(result).to.eq(true);

            res = await tickBitmap.isInitialized_2bdc2fd3(1);
            result = Boolean(res[0].toNumber());
            expect(result).to.eq(false);
        })
    })

    describe('#flipTick', () => {
        it('flips only the specified tick', async () => {
            //-230
            await tickBitmap.flipTick_8815912f(new BN(-230).toTwos(24).toString());

            //-230
            let res = await tickBitmap.isInitialized_2bdc2fd3(new BN(-230).toTwos(24).toString());
            let result = Boolean(res[0].toNumber());
            expect(result).to.eq(true);

            //-231
            res = await tickBitmap.isInitialized_2bdc2fd3(new BN(-231).toTwos(24).toString());
            result = Boolean(res[0].toNumber());
            expect(result).to.eq(false);

            //-229
            res = await tickBitmap.isInitialized_2bdc2fd3(new BN(-229).toTwos(24).toString());
            result = Boolean(res[0].toNumber());
            expect(result).to.eq(false);

            //-230 + 256
            res = await tickBitmap.isInitialized_2bdc2fd3(26);
            result = Boolean(res[0].toNumber());
            expect(result).to.eq(false);

            //-230 - 256
            res = await tickBitmap.isInitialized_2bdc2fd3(new BN(-486).toTwos(24).toString());
            result = Boolean(res[0].toNumber());
            expect(result).to.eq(false);

            //-230
            await tickBitmap.flipTick_8815912f(new BN(-230).toTwos(24).toString());

            //-230
            res = await tickBitmap.isInitialized_2bdc2fd3(new BN(-230).toTwos(24).toString());
            result = Boolean(res[0].toNumber());
            expect(result).to.eq(false);

            //-231
            res = await tickBitmap.isInitialized_2bdc2fd3(new BN(-231).toTwos(24).toString());
            result = Boolean(res[0].toNumber());
            expect(result).to.eq(false);

            //-229
            res = await tickBitmap.isInitialized_2bdc2fd3(new BN(-229).toTwos(24).toString());
            result = Boolean(res[0].toNumber());
            expect(result).to.eq(false);

            //-230 + 256
            res = await tickBitmap.isInitialized_2bdc2fd3(26);
            result = Boolean(res[0].toNumber());
            expect(result).to.eq(false);

            //-230 - 256
            res = await tickBitmap.isInitialized_2bdc2fd3(new BN(-486).toTwos(24).toString());
            result = Boolean(res[0].toNumber());
            expect(result).to.eq(false);
        })

        it('reverts only itself', async () => {
            //-230
            await tickBitmap.flipTick_8815912f(new BN(-230).toTwos(24).toString())
            //-259
            await tickBitmap.flipTick_8815912f(new BN(-259).toTwos(24).toString())
            //-229
            await tickBitmap.flipTick_8815912f(new BN(-229).toTwos(24).toString())
            await tickBitmap.flipTick_8815912f(500)
            //-259
            await tickBitmap.flipTick_8815912f(new BN(-259).toTwos(24).toString())
            //-229
            await tickBitmap.flipTick_8815912f(new BN(-229).toTwos(24).toString())
            //-259
            await tickBitmap.flipTick_8815912f(new BN(-259).toTwos(24).toString())

            //-259
            let res = await tickBitmap.isInitialized_2bdc2fd3(new BN(-259).toTwos(24).toString());
            let result = Boolean(res[0].toNumber())
            expect(result).to.eq(true);

            //-229
            res = await tickBitmap.isInitialized_2bdc2fd3(new BN(-229).toTwos(24).toString());
            result = Boolean(res[0].toNumber())
            expect(result).to.eq(false);
        })
    })

    describe('#nextInitializedTickWithinOneWord', () => {
        beforeEach('set up some ticks', async () => {
            // word boundaries are at multiples of 256
            await initTicks([-200, -55, -4, 70, 78, 84, 139, 240, 535]);
        })

        describe('lte = false', () => {
            it('returns tick to right if at initialized tick', async () => {
                const { __warp_usrid4_next, __warp_usrid5_initialized } = 
                    await tickBitmap.nextInitializedTickWithinOneWord_3e7ba228(78, 0)
                expect(__warp_usrid4_next.toString()).to.eq("84");
                expect(__warp_usrid5_initialized.toString()).to.eq("1");
            });
            it('returns tick to right if at initialized tick', async () => {
                const { __warp_usrid4_next, __warp_usrid5_initialized } = 
                    await tickBitmap.nextInitializedTickWithinOneWord_3e7ba228(new BN(-55).toTwos(24).toString(), 0)

                expect(__warp_usrid4_next.toString()).to.eq(new BN(-4).toTwos(24).toString());
                expect(__warp_usrid5_initialized.toString()).to.eq("1");
            });
            it('returns the tick directly to the right', async () => {
                const { __warp_usrid4_next, __warp_usrid5_initialized } = 
                    await tickBitmap.nextInitializedTickWithinOneWord_3e7ba228(77, 0)

                expect(__warp_usrid4_next.toString()).to.eq("78");
                expect(__warp_usrid5_initialized.toString()).to.eq("1");
            });
            it('returns the tick directly to the right', async () => {
                const { __warp_usrid4_next, __warp_usrid5_initialized } = 
                    await tickBitmap.nextInitializedTickWithinOneWord_3e7ba228(new BN(-56).toTwos(24).toString(), 0)

                expect(__warp_usrid4_next.toString()).to.eq(new BN(-55).toTwos(24).toString());
                expect(__warp_usrid5_initialized.toString()).to.eq("1");
            });
            it('returns the next words initialized tick if on the right boundary', async () => { // FAILS
                const { __warp_usrid4_next, __warp_usrid5_initialized } = 
                    await tickBitmap.nextInitializedTickWithinOneWord_3e7ba228(255, 0)

                expect(__warp_usrid4_next.toString()).to.eq("511");
                expect(__warp_usrid5_initialized.toString()).to.eq("0");
            });
            it('returns the next words initialized tick if on the right boundary', async () => {
                const { __warp_usrid4_next, __warp_usrid5_initialized } = 
                    await tickBitmap.nextInitializedTickWithinOneWord_3e7ba228(new BN(-257).toTwos(24).toString(), 0)

                expect(__warp_usrid4_next.toString()).to.eq(new BN(-200).toTwos(24).toString());
                expect(__warp_usrid5_initialized.toString()).to.eq("1");
            });
            it('returns the next initialized tick from the next word', async () => {
                await tickBitmap.flipTick_8815912f(340);
                const { __warp_usrid4_next, __warp_usrid5_initialized } = await tickBitmap.nextInitializedTickWithinOneWord_3e7ba228(328, 0)
                expect(__warp_usrid4_next.toString()).to.eq('340');
                expect(__warp_usrid5_initialized.toString()).to.eq('1');
            });
            it('does not exceed boundary', async () => {
                const { __warp_usrid4_next, __warp_usrid5_initialized } = await tickBitmap.nextInitializedTickWithinOneWord_3e7ba228(508, 0)
                expect(__warp_usrid4_next).to.eq('511');
                expect(__warp_usrid5_initialized).to.eq('0');
            });
            it('skips entire word', async () => { // FAILS
                const { __warp_usrid4_next, __warp_usrid5_initialized } = await tickBitmap.nextInitializedTickWithinOneWord_3e7ba228(255, 0)
                expect(__warp_usrid4_next).to.eq('511');
                expect(__warp_usrid5_initialized).to.eq('0');
            });
            it('skips half word', async () => {
                const { __warp_usrid4_next, __warp_usrid5_initialized } = await tickBitmap.nextInitializedTickWithinOneWord_3e7ba228(383, 0)
                expect(__warp_usrid4_next).to.eq('511')
                expect(__warp_usrid5_initialized).to.eq('0')
            });
        });

        describe('lte = true', () => {
            it('returns same tick if initialized', async () => {
              const { __warp_usrid4_next , __warp_usrid5_initialized } = await tickBitmap.nextInitializedTickWithinOneWord_3e7ba228(78, 1)
      
              expect(__warp_usrid4_next.toString()).to.eq('78')
              expect(__warp_usrid5_initialized.toString()).to.eq('1')
            })
            it('returns tick directly to the left of input tick if not initialized', async () => {
              const { __warp_usrid4_next, __warp_usrid5_initialized } = await tickBitmap.nextInitializedTickWithinOneWord_3e7ba228(79, 1)
      
              expect(__warp_usrid4_next.toString()).to.eq('78')
              expect(__warp_usrid5_initialized.toString()).to.eq('1')
            })
            it('will not exceed the word boundary', async () => {
              const { __warp_usrid4_next, __warp_usrid5_initialized } = await tickBitmap.nextInitializedTickWithinOneWord_3e7ba228(258, 1)
      
              expect(__warp_usrid4_next.toString()).to.eq('256')
              expect(__warp_usrid5_initialized.toString()).to.eq('0')
            })
            it('at the word boundary', async () => {
              const { __warp_usrid4_next, __warp_usrid5_initialized } = await tickBitmap.nextInitializedTickWithinOneWord_3e7ba228(256, 1)
      
              expect(__warp_usrid4_next.toString()).to.eq('256')
              expect(__warp_usrid5_initialized.toString()).to.eq('0')
            })
            it('word boundary less 1 (next initialized tick in next word)', async () => {
              const { __warp_usrid4_next, __warp_usrid5_initialized } = await tickBitmap.nextInitializedTickWithinOneWord_3e7ba228(72, 1)
      
              expect(__warp_usrid4_next.toString()).to.eq('70')
              expect(__warp_usrid5_initialized.toString()).to.eq('1')
            })
            it('word boundary', async () => { // FAILS
              const { __warp_usrid4_next, __warp_usrid5_initialized } = 
                await tickBitmap.nextInitializedTickWithinOneWord_3e7ba228(new BN(-257).toTwos(24).toString(), 1)
      
              expect(__warp_usrid4_next.toString()).to.eq(new BN(-512).toTwos(24).toString());
              expect(__warp_usrid5_initialized.toString()).to.eq('0')
            })
            it('entire empty word', async () => { // FAILS
              const { __warp_usrid4_next, __warp_usrid5_initialized } = await tickBitmap.nextInitializedTickWithinOneWord_3e7ba228(1023, 1)
      
              expect(__warp_usrid4_next.toString()).to.eq('768')
              expect(__warp_usrid5_initialized.toString()).to.eq('0')
            })
            it('halfway through empty word', async () => { // FAILS
              const { __warp_usrid4_next, __warp_usrid5_initialized } = await tickBitmap.nextInitializedTickWithinOneWord_3e7ba228(900, 1)
      
              expect(__warp_usrid4_next.toString()).to.eq('768')
              expect(__warp_usrid5_initialized.toString()).to.eq('0')
            })
            it('boundary is initialized', async () => {
              await tickBitmap.flipTick_8815912f(329)
              const { __warp_usrid4_next, __warp_usrid5_initialized } = await tickBitmap.nextInitializedTickWithinOneWord_3e7ba228(456, 1)
      
              expect(__warp_usrid4_next.toString()).to.eq('329')
              expect(__warp_usrid5_initialized.toString()).to.eq('1')
            })
        })
    })
})