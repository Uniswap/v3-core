import { createDraft, current, Draft } from 'immer'

export type GenericMigrationStep<S, C, O> = (state: Draft<S>, config: C) => Promise<O>

export async function* migrate<S, C, O>({
  onStateChange,
  initialState,
  config,
  steps,
}: {
  initialState: S
  onStateChange: (newState: S) => Promise<void>
  config: C
  steps: GenericMigrationStep<S, C, O>[]
}): AsyncGenerator<O, void, void> {
  const mutableState: Draft<S> = createDraft(initialState)

  for (let i = 0; i < steps.length; i++) {
    const output = await steps[i](mutableState, config)
    const nextState: S = current(mutableState) as S // have to cast because immer doesn't have proper typings
    await onStateChange(nextState)
    yield output
  }
}
