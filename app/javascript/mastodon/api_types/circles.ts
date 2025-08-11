// See app/serializers/rest/circle_serializer.rb

export interface ApiCircleJSON {
  id: string;
  title: string;
  list?: {
    id: string;
    title: string;
  } | null;
}
