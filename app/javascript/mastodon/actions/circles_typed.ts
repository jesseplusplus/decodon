import {
  apiCreateCircle,
  apiUpdateCircle,
  apiGetCircles,
  apiGetCircle,
  apiDeleteCircle,
} from 'mastodon/api/circles';
import type { Circle } from 'mastodon/models/circle';
import { createDataLoadingThunk } from 'mastodon/store/typed_functions';

export const createCircle = createDataLoadingThunk(
  'circle/create',
  (circle: Partial<Circle>) => apiCreateCircle(circle),
);

export const updateCircle = createDataLoadingThunk(
  'circle/update',
  (circle: Partial<Circle>) => apiUpdateCircle(circle),
);

export const fetchCircles = createDataLoadingThunk('circles/fetch', () =>
  apiGetCircles(),
);

export const fetchCircle = createDataLoadingThunk(
  'circle/fetch',
  ({ id }: { id: string }) => apiGetCircle(id),
);

export const deleteCircle = createDataLoadingThunk(
  'circle/delete',
  ({ id }: { id: string }) => apiDeleteCircle(id),
);
